# Orca terminal theme — repo-first theming

Theme an Orca repo's terminals by committing **one file** — no shell edits, ever.

## How it works (30-second mental model)

- Every interactive shell inside an Orca worktree (`$ORCA_WORKTREE_ID` set) runs a loader at startup: `~/.config/orca/orca-theme.zsh`.
- The loader asks `orca` which repo this worktree belongs to, looks for a small JSON theme file, and — if it finds one — paints the terminal via OSC escapes (background/foreground/cursor/16-color palette).
- The loader itself carries **zero repo-specific data**. Every repo's colors are a **data file**, not code. Add a repo by dropping a file; never by editing zsh.
- A theme has a few independent parts (two main halves plus an optional statusline accent):

| Part | Controls | Applied by | When |
|---|---|---|---|
| Terminal OSC colors | background / foreground / cursor / 16-color ANSI palette | the loader, reading the theme JSON | automatically, at shell startup (synchronous, before the prompt), then **re-asserted** on three triggers so Orca recreating the renderer surface (app restart, tab re-activation) can't drop them: before every prompt (`precmd`), on every pty resize (`TRAPWINCH` — a fresh surface fits itself on attach), and — while a TUI like Claude Code owns the pane — on every statusline render (`orca-theme osc` → `/dev/tty`) |
| Claude Code theme | the dim **`inactive`** text token (version/model/cwd line) + overall `base` | `orca-theme install`, generating `~/.claude/themes/<slug>.json` + setting the project's `theme` selection | manually, once per repo (or after editing the `claudeCode` block); needs a Claude Code relaunch |
| Claude Code statusline | the **project-name color** in the statusline (the left-most `dir_display`) | the statusline script (`~/.claude/statusline-command.sh`) calling `orca-theme statusline-color` | automatically, every statusline render (no relaunch — the script reads the theme file live) |

The Claude Code half exists because **the dim grey text is not a terminal color** — it's Claude Code's own `inactive` theme token, and OSC escapes cannot touch it. It can only be fixed through a Claude Code theme file + a `"theme"` selection in Claude Code's own settings.

The statusline part is different again: the project name is drawn by a **user script**, not by a theme token, so neither OSC nor a Claude Code theme file can set it. Instead the script asks `orca-theme statusline-color` for a color and paints the name itself. It needs no `install` step and no relaunch. See [Claude Code statusline — the project-name color](#claude-code-statusline--the-project-name-color).

## The repo-first model

- **Adding a theme = committing `<repo>/design/terminal-theme.json`.** Because git worktrees share tracked files, that one commit themes *every* Orca worktree of that repo automatically, on every machine that checks it out.
- The central directory `~/.config/orca/themes/<displayName>.json` is only a **fallback / local override** — for a repo you can't commit to, or want to retune on this machine without touching the repo.
- **Precedence (highest wins): central override → in-repo file → none.** A file placed centrally always beats a committed in-repo file (the git-config model: a deliberate local action beats the shared default).

| Precedence | Location | Role |
|---|---|---|
| 1 (highest) | `~/.config/orca/themes/<displayName>.json` | Central override — machine-local, wins if present |
| 2 | `<worktree>/design/terminal-theme.json` | In-repo — **primary source of truth**, commit it |
| 3 (none found) | — | Terminal resets to its own defaults (OSC `110`/`111`/`112`/`104`) |

`<displayName>` is the repo's Orca display name **exactly as `orca repo list` prints it** (the lookup key) — not the folder name, not the JSON file's `project` field, and never a per-worktree display name (worktrees named `main`/`master` collide across repos).

## What stays global vs. what lives in-repo

| Stays global (`~/.config/orca/`) | Why | Lives in-repo | Why |
|---|---|---|---|
| `orca/orca-theme.zsh` — the loader | Runs at *every* shell startup, regardless of repo; has no per-repo data left in it. Sourced from `~/.zshrc`. | `design/terminal-theme.json` — the theme data (terminal colors + `claudeCode` block) | This is the whole theme; committing it is the entire "add a theme" step |
| `orca/bin/orca-theme` — the helper CLI | Generic tooling that operates on whichever repo you point it at. On PATH via `~/.config/orca/bin`. | `.claude/settings.local.json` (personal) or committed `.claude/settings.json` — the Claude Code **selection** (`"theme":"custom:<slug>"`) | Keeps the Claude Code half repo-local too, as far as Claude Code allows |
| `orca/themes/` — central override store | By nature machine-local; empty unless you deliberately add an override | | |
| `~/.claude/themes/<slug>.json` | **Generated**, not source — Claude Code themes are global-only, so this file is regenerated from the repo's `claudeCode` section by `orca-theme install`. Safe to delete/regenerate. | | |
| `~/.claude/settings.json` (user-global) | Stays `"theme":"auto"` — no per-repo keys ever land here | | |

## Schema reference

One schema, used identically whether the file lives in-repo or centrally: `<worktree>/design/terminal-theme.json` or `~/.config/orca/themes/<displayName>.json`.

**Top level**

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | no | Display label, e.g. `"Forecast Card"` |
| `project` | string | no | Human tag, e.g. `"weather-range"`; also the default base for `claudeCode.slug` (`"<project>-night"`) — **not** used for file lookup |
| `source` | string | no | Free-text provenance note |
| `variants.day`, `variants.night` | object | for terminal theming, at least one | `{ background, foreground, cursor }` — see below |
| `palette` | array of 16 `"#rrggbb"` strings | no | ANSI slots `0`–`15`, shared across variants, emitted via OSC `4`. Omit to keep the terminal's own palette. |
| `claudeCode` | object | no | The Claude Code half — see below |
| `colorspace` | string | no | Optional free-text annotation (e.g. `"srgb"`) recording what space the hexes are in. **Ignored by the loader/CLI** — like any unknown key, it's documentation only. Useful after a P3→sRGB conversion. |

**`variants.<day\|night>`** — each of the three colors is independently optional; a missing color is simply not emitted, so the terminal keeps its own default for that slot.

| Field | Type | Notes |
|---|---|---|
| `background` | `"#rrggbb"` | OSC `11` |
| `foreground` | `"#rrggbb"` | OSC `10` |
| `cursor` | `"#rrggbb"` | OSC `12` |

**`claudeCode`**

| Field | Type | Default if absent | Notes |
|---|---|---|---|
| `slug` | string | `"<project>-night"` | The `~/.claude/themes/` namespace is **flat and global** — always scope this per repo to avoid collisions |
| `base` | enum: `dark \| light \| dark-daltonized \| light-daltonized \| dark-ansi \| light-ansi` | `"dark"` | If **present but invalid**, `orca-theme install` hard-errors and lists the allowed values — it does not silently fall back |
| `inactive` | `"#rrggbb"` | — | Shorthand for the dim-text fix; folded into `overrides.inactive` **only if** `overrides.inactive` is absent |
| `overrides` | object (token → color) | `{}` | Full Claude Code override map, mirrors Claude Code's own `themes/*.json` `overrides` |
| `statusName` | `"#rrggbb"` **or** `{ day, night }` | — | Color of the **project name** in the Claude Code statusline. A plain hex string, or a per-variant object (variant-selected, with graceful fallback to the other variant). Read live by `orca-theme statusline-color`; no `install` step. Absent → statusline falls back to the repo's Orca badge color, then to its own default `#cc44ff`. Renders on the terminal **background**, so pick a color readable there. |

Color forms: terminal OSC colors should be `#rrggbb`. Claude Code's own color fields additionally accept `#rgb`, `rgb(r,g,b)`, `ansi256(n)`, and `ansi:<name>`.

Enum handling differs by field, on purpose:

- `ORCA_THEME_VARIANT` (day/night) — an invalid value **falls back silently** to `night`.
- `claudeCode.base` — an invalid value **is a hard error** from `orca-theme install` (it never guesses which theme you meant).

**Complete example** — the actual `weather-range` file (`/Users/tal/Projects/weather-range/design/terminal-theme.json`):

```json
{
  "name": "Forecast Card",
  "project": "weather-range",
  "source": "app UI colours (sampled P3, converted P3->sRGB); applied per-directory via OSC 10/11/12/4",
  "variants": {
    "day":   { "background": "#1893f1", "foreground": "#ffffff", "cursor": "#9e01d3" },
    "night": { "background": "#115690", "foreground": "#e6ffff", "cursor": "#1893f1" }
  },
  "palette": [
    "#1b3557", "#ff3d7f", "#21c7e0", "#ffd23f",
    "#269bf8", "#c04dff", "#7ff6ff", "#e6ffff",
    "#b0c3d8", "#ff7aa6", "#6fe3ff", "#ffe07a",
    "#8fc2ff", "#d98cff", "#b3fbff", "#ffffff"
  ],
  "claudeCode": {
    "slug": "weather-range-night",
    "base": "dark",
    "inactive": "#c4c4c4"
  },
  "colorspace": "srgb"
}
```

A ready-to-copy annotated template (with an inline `_readme`/`_docs`) lives at `/Users/tal/.config/orca/themes/_template.json`.

## Quickstart — add a theme to a repo you own

1. `orca-theme new <repo>` — scaffolds `<repo>/design/terminal-theme.json` (add `--from-badge` to seed colors from the repo's Orca badge color).
2. Edit the `day`/`night` colors and the 16-entry `palette` to taste.
3. `orca-theme preview` (run from inside that repo's Orca terminal) or `orca-theme preview <repo>` from anywhere — applies the theme to *this* terminal immediately, no new shell needed.
4. Commit the file. Every Orca worktree of the repo is themed automatically, on every machine.
5. Optional: `orca-theme install <repo>` to wire up the `claudeCode` block (the dim-text fix).

## Claude Code half — install step

- **Why separate:** Claude Code theme *definitions* are global-only (`~/.claude/themes/<slug>.json`) — there's no supported `<repo>/.claude/themes/`. So the repo's `claudeCode` block is the source of truth, and `orca-theme install` **generates** the global definition from it.
- **Selection stays in-repo:** `install` writes `"theme":"custom:<slug>"` into `<repo>/.claude/settings.local.json` by default (personal, gitignored). Pass `--shared` to write it into the committed `<repo>/.claude/settings.json` instead so teammates inherit it — the CLI flags this as *unverified* whether Claude Code honors a project-level `theme` key the same way; confirm with `/status` after relaunch.
- **Settings precedence** (highest wins): project `.claude/settings.local.json` → project `.claude/settings.json` → user `~/.claude/settings.json` (which stays `"theme":"auto"` — verified on this machine).
- **No `claudeCode` section → no-op.** `install` prints a friendly message and does nothing; that repo just gets a terminal-only theme.
- **Reload caveats:**
  - Changing the **selection** (`"theme": ...` key) needs a full Claude Code **relaunch** — it does not hot-reload.
  - Editing an **already-selected** definition file hot-reloads live, *except* the very first file ever written into a previously-nonexistent `~/.claude/themes/` — that needs one restart. (Not a concern here: the directory already exists.)
- **Slugs share one flat global namespace** across every project — always repo-scope them (the default `"<project>-night"` already does this).

## Claude Code statusline — the project-name color

The Claude Code statusline (the line showing the project name, git branch, context circle, model) is drawn by a **user script** — here `~/.claude/statusline-command.sh`. The left-most token is the project name (`dir_display`), historically a hardcoded purple `#cc44ff` (matched to the starship prompt). That color is now **repo-aware**: the script asks `orca-theme statusline-color` for a per-repo color and paints the name with it, falling back to the purple when there's no theme.

- **Why a separate mechanism:** the project name is printed by the script itself, not by a Claude Code theme token or an OSC escape — so neither the terminal half nor the `claudeCode` theme file can touch it. The only way in is the script asking for a color.
- **No install, no relaunch.** Unlike the `claudeCode` theme (which needs `orca-theme install` + a relaunch), the statusline reads the theme file **live** on every render. Edit `statusName`, and the next render picks it up.

**Resolution order** (`orca-theme statusline-color [<dir>]` prints the first that resolves, else nothing):

| # | Source | Needs `orca`? |
|---|---|---|
| 1 | `claudeCode.statusName` in the repo's theme file (central override → in-repo, same precedence as everything else) | no (fast path) — unless a real central override exists, which is keyed by displayName |
| 2 | the repo's Orca **badge color** (`orca repo show … .badgeColor`) | yes — one `orca` call, only when `statusName` is absent |
| 3 | nothing printed → the statusline keeps its own default `#cc44ff` | no |

- `statusName` accepts a plain `"#rrggbb"` **or** a `{ "day": "#…", "night": "#…" }` object, variant-selected by `ORCA_THEME_VARIANT` (default `night`; the CLI's `--variant` overrides it). The statusline inherits `ORCA_THEME_VARIANT` from the shell that launched Claude Code.
- **`<dir>`** is where to look for an in-repo theme; the statusline passes its `project_dir`. The repo identity for the badge fallback comes from `$ORCA_WORKTREE_ID` (inherited from the launching Orca shell), so the badge fallback only works when Claude Code was launched from an Orca worktree. `statusName` works regardless — it's read straight from the file.
- **Performance:** the common paths (a `statusName` hit, or no theme at all) are ~10 ms and make **zero** `orca` calls. Only the badge fallback pays one `orca` call (~0.15 s); the statusline wraps the call in a 1 s `timeout`/`gtimeout` (when present) so a hung `orca` can never freeze the line, and only re-renders (throttled) pay it.
- **Wiring:** the statusline script lives at `~/.claude/statusline-command.sh` — **not** under `~/.config/orca/`; it is chezmoi-tracked separately (`dot_claude/executable_statusline-command.sh`), so sync it alongside the engine files when the integration block changes. The integration is a self-contained block in the middle of that script (guarded on `[ -x ~/.config/orca/bin/orca-theme ]`), so removing `orca-theme` degrades cleanly to the purple default. Inspect the resolved color for the current repo with `orca-theme doctor` (a `statusline project-name color:` line) or `orca-theme statusline-color`.

## Repainting after Orca recreates the surface

Orca hosts every shell in a persistent daemon. When the app restarts, or a pane is re-activated after being backgrounded, the daemon keeps the shell + pty alive and only **recreates the renderer surface** — which comes up on its own default colors. The OSC state lived in the old surface, the shell never re-runs `~/.zshrc`, and nothing outside the pane can write to it (the engine only ever writes to the shell's own stdout). So the repaint has to come from *inside* the pane, and there are three triggers depending on who owns the foreground:

| Trigger | Fires when | Covers | Lives in |
|---|---|---|---|
| `precmd` | zsh is about to draw a prompt | a shell that was mid-command — repaints when the command finishes | loader |
| `TRAPWINCH` | the pty is resized — a fresh surface fits itself to the pane on attach and sends `SIGWINCH` to the foreground process group | a shell **idling at its prompt** — repaints instantly, no Enter needed | loader |
| statusline render | Claude Code re-runs `~/.claude/statusline-command.sh` (throttled, on state changes) | a pane where a **TUI** owns the foreground — the shell can't run either hook until the TUI exits, so the statusline calls `orca-theme osc` and writes the payload straight to `/dev/tty` | statusline script + CLI |

- All three re-emit the **same** payload (the loader's cached `$_ORCA_THEME_OSC`, or the CLI's fresh resolution of the same file): color-only OSC, no cursor movement, nothing visible, idempotent — same colors, no flicker.
- The `TRAPWINCH` is chained onto any `TRAPWINCH` that already existed, installed once per shell, and is a no-op when the repo has no theme. Only shells opened after this landed have it.
- The statusline path is gated on `$ORCA_WORKTREE_ID` (inherited from the launching Orca shell), so a non-Orca terminal is never written to. It repaints on the *next* statusline render, not the instant the tab comes back — Claude Code re-renders often enough while working that it's near-instant; a Claude Code sitting fully idle repaints when anything next happens.
- **Which trigger actually fired?** Set `ORCA_THEME_DEBUG=/tmp/orca-theme.log` in the shell (before launching Claude Code, for the statusline path) and each repaint appends `HH:MM:SS <pid> precmd|winch|statusline`.
- The real fix is upstream: Orca persisting OSC `10`/`11`/`12`/`4` across surface recreation. Everything here is a workaround for that.

## Variant selection

- `ORCA_THEME_VARIANT=day` or `ORCA_THEME_VARIANT=night` selects which variant is applied; **default is `night`**, and an invalid value silently falls back to `night`.
- Preview either one on demand without touching the env var: `orca-theme preview --variant day`.

## Helper CLI reference (`/Users/tal/.config/orca/bin/orca-theme`)

| Command | Does |
|---|---|
| `orca-theme list` | Table of every registered repo: theme source (central/in-repo/none), day/night/palette presence, Claude Code slug, whether it's installed, whether it's selected, badge color |
| `orca-theme preview [<repo>] [--variant day\|night]` | Applies a theme to *this* terminal right now, framed as temporary. Default repo = current Orca worktree. |
| `orca-theme apply [<repo>]` | Same as `preview`, without the "temporary" framing — handy right after editing a theme file |
| `orca-theme reset` | Resets this terminal's colors to its own defaults (OSC `110`/`111`/`112`/`104`) |
| `orca-theme new <repo>` / `scaffold <repo>` `[--central] [--from-badge] [--force]` | Scaffolds the theme file — in-repo by default; `--central` targets the override dir instead; `--from-badge` seeds colors from the repo's Orca badge; `--force` overwrites an existing file |
| `orca-theme install [<repo>] [--shared]` | Generates the Claude Code theme definition + sets the selection (see above) |
| `orca-theme statusline-color [<dir>] [--variant day\|night]` | Prints the statusline project-name color (`claudeCode.statusName` → Orca badge → nothing) as `#rrggbb`. Called by `~/.claude/statusline-command.sh`; `<dir>` defaults to the current Orca worktree / `$PWD` |
| `orca-theme osc [<dir>] [--variant day\|night]` | Prints the raw OSC `10`/`11`/`12`/`4` payload for the resolved theme (no newline), or nothing when there's no theme / the file is malformed. Same `<dir>`/`--variant` rules as `statusline-color`. Called by `~/.claude/statusline-command.sh` on every render and written to `/dev/tty` — the TUI-side repaint (see [Repainting after Orca recreates the surface](#repainting-after-orca-recreates-the-surface)) |
| `orca-theme doctor` | Checks `orca`/`jq` on PATH, `~/.claude/themes` writability, the current repo's resolved theme source, and its resolved statusline project-name color |
| `orca-theme help` | Usage |

Env knobs (all four also documented at the top of `orca-theme.zsh`):

| Var | Values | Default | Effect |
|---|---|---|---|
| `ORCA_THEME_VARIANT` | `day` \| `night` | `night` | Which variant is applied; invalid → `night` |
| `ORCA_THEME_DIR` | a path | `~/.config/orca/themes` | Central override directory — mainly for testing |
| `ORCA_THEME_QUIET` | any non-empty value | unset | Silences the one-line "need orca and jq" stderr log |
| `ORCA_THEME_DEBUG` | a file path | unset | Appends one `HH:MM:SS <pid> precmd\|winch\|statusline` line per repaint — to see which trigger fires when a pane comes back |

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| No colors ever change | `orca` or `jq` missing from PATH | `orca-theme doctor`; install the missing tool |
| Background reset to default after an **Orca app restart** or **re-activating a tab** | Orca hosts shells in a persistent daemon, so it recreates only the renderer surface (default background) — the shell survives and the loader never re-runs | Handled by three re-emit triggers (`precmd`, `TRAPWINCH`, statusline) — see [Repainting after Orca recreates the surface](#repainting-after-orca-recreates-the-surface). **Existing** shells opened before a trigger landed won't have it — open a **new** Orca terminal to pick it up (a plain restart won't backfill old shells, since the daemon keeps them alive) |
| A shell **idling at its prompt** stays un-themed until you press Enter | Only `precmd` is firing — either the shell predates the `TRAPWINCH` trigger, or Orca didn't send `SIGWINCH` on re-attach | Open a new Orca terminal; if it still needs Enter, set `ORCA_THEME_DEBUG` and check whether any `winch` line appears when the pane comes back — no line means no resize on attach, and the fallback is the next prompt |
| A pane running **Claude Code** stays un-themed | The shell can't run its hooks while the TUI owns the foreground; the statusline path needs `$ORCA_WORKTREE_ID` in Claude Code's env and `orca-theme osc` resolving a theme | Launch Claude Code from the Orca shell (not from elsewhere); run `orca-theme osc \| cat -v` in that worktree — empty output means no theme resolved; `ORCA_THEME_DEBUG` should show `statusline` lines on each render |
| The missing-tool message is annoying | — | `export ORCA_THEME_QUIET=1` |
| Edited the JSON but the terminal didn't change | The loader only runs once, at shell startup | `orca-theme apply` to see it now, or open a **new** Orca terminal — editing the file never affects an already-running shell |
| Edited the **in-repo** file but nothing changed | A central override exists for that repo's displayName and wins by precedence | Check/remove `~/.config/orca/themes/<displayName>.json` — or keep it, if the override is intentional |
| Theme file exists but repo still resets to defaults | Malformed JSON, or fewer than 3 lines of output (missing `variants.<variant>` entirely) | Both the loader and the CLI treat unparseable/too-short output as "no theme" and reset; validate with `jq . <file>` |
| Claude Code's dim text is still the wrong grey | `orca-theme install` hasn't been run, or Claude Code wasn't relaunched after | Run `orca-theme install <repo>`, then fully quit and reopen Claude Code (the selection key doesn't hot-reload) |
| Two repos fight over the same Claude Code theme | `~/.claude/themes/` is one flat global namespace | Give `claudeCode.slug` a repo-scoped name (the default `"<project>-night"` already avoids this) |
| Statusline project name is still the default purple | No `claudeCode.statusName`, and either no Orca badge or Claude Code wasn't launched from an Orca worktree (`$ORCA_WORKTREE_ID` unset → no badge fallback) | Add `claudeCode.statusName` to the theme file (works everywhere, no `orca` needed); confirm with `orca-theme statusline-color` / `orca-theme doctor` |
| Statusline color didn't change after editing `statusName` | The statusline re-renders on a throttle, and command substitution is cached per render | Trigger a render (type in Claude Code); unlike the `claudeCode` theme, no relaunch is needed — the file is read live |
| Statusline color is wrong / an old value | A central override (`~/.config/orca/themes/<displayName>.json`) has its own `statusName` and wins by precedence | Check/remove the central override, or edit its `statusName` |
| `orca-theme new <repo>` / `install <repo>` (named explicitly) touches an unexpected worktree | Naming a `<repo>` resolves to its **main registered path** (`orca repo list`'s `.path`), not any particular worktree | Run the command with **no** `<repo>` argument from inside the target worktree's own shell instead (it then uses `$ORCA_WORKTREE_ID`'s real path) |
| `orca-theme install --shared` selection doesn't seem to apply | Unverified whether Claude Code honors a `theme` key from committed `settings.json` the same as `settings.local.json` | Confirm with `/status` after relaunch; fall back to the personal `settings.local.json` selection if not |

## Performance notes

- **Synchronous (on purpose):** the loader runs inline during `~/.zshrc` sourcing, *before* the line editor (ZLE) takes over the terminal. It used to run backgrounded (`&!`), but a background job writing OSC escapes to the TTY races with ZLE once the prompt is up and can make **Tab/Backspace stop working** (the terminal's escape parser eats the keystrokes). Inline-before-prompt has no concurrent writer.
- **Guarded:** the very first check is `[[ -n "$ORCA_WORKTREE_ID" ]]` — every non-Orca shell exits in O(1), zero `orca`/`jq` calls, zero cost.
- **Cost when inside an Orca worktree:** one `orca repo show` call (~0.15s, for the displayName) plus small `jq` parses, paid synchronously at startup. Only Orca-worktree shells pay it. (Possible future optimization: skip the `orca` call entirely when the central override dir is empty, since the in-repo file is found from `$ORCA_WORKTREE_ID`'s path alone.)

## Wiring & chezmoi note

The whole engine now lives under `~/.config/orca/` — Orca's own config directory (it also holds `agent-hooks/`, `keybindings.json`, and `worktrees/`). Two lines in `~/.zshrc` wire it up:

- `export PATH="$PATH:$HOME/.config/orca/bin"` — puts the `orca-theme` CLI on PATH.
- `source "$HOME/.config/orca/orca-theme.zsh"` — loads the theme engine at startup (it is no longer picked up by the `~/.config/zsh/*.zsh` glob).

chezmoi: **do not** wholesale-track `~/.config/orca/` — it contains Orca's live `worktrees/` (git checkouts, transient data). Only these four theme files are individually tracked: `orca/orca-theme.zsh`, `orca/bin/orca-theme`, `orca/themes/_template.json`, `orca/README.md` (plus the two `~/.zshrc` wiring lines, and `~/.claude/statusline-command.sh` as `dot_claude/executable_statusline-command.sh`). Ask before syncing changes to them. In-repo theme files (`<repo>/design/terminal-theme.json`) are **not** chezmoi's concern at all — they live in each project's own git history and travel with the repo.
