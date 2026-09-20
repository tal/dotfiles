# Custom params for `cc` / `cx`

Per-project, run-by-run knobs for the `cc` (claude) and `cx` (codex) shell
functions. You describe **intent** ("make this MCP available", "use this
model", "crank effort") in a YAML file, and the wrapper materializes it into
whatever flags claude vs codex actually want — so the same short token does the
right thing for both tools.

```sh
cc fable beeper-mcp        # fable model + Beeper MCP available, just this run
cx think staging           # high reasoning effort + staging env, just this run
cc big planmode "review the diff"
```

A param is a named bundle under `params:`:

```yaml
# yaml-language-server: $schema=./custom-params.schema.json
params:
  fable:  { description: Latest Fable, model: fable }
  think:  { description: More effort (codex), effort: high, harnesses: [codex] }
  beeper-mcp:
    description: Beeper MCP
    mcpServers:
      beeper: { command: npx, args: [-y, "@beeper/desktop-api-mcp@latest"] }
```

Parsed with `yq` if present, else macOS `ruby` (psych), else `python3`+PyYAML;
the merge/materialization is `jq`. Legacy `.json` files still load. The
`# yaml-language-server:` line wires up editor autocomplete/validation against
[`custom-params.schema.json`](./custom-params.schema.json).

## Where the files live (merged, not either/or)

Params come from **two tiers that merge**, global first then project on top:

```
~/.config/coding-agents/custom-params.yaml          # GLOBAL base (everywhere)
<project>/.config/coding-agents/custom-params.yaml  # project, layered on top
```

Accepted basenames per directory, first match wins: `custom-params.yaml`,
`custom-params.yml`, then `custom-params.json`.

`cc`/`cx` walk **up** from `$PWD` collecting every config on the way (stopping at
`$HOME` / `/`), always including the global home file as the base, then **merge**
them. On a same-named param the **nearer (deeper) file wins wholesale** — so a
project can pin/override `fable`, `opus`, etc., while every other global param
still applies inside that project. This is a real merge, not nearest-wins: a
global alias is **not** shadowed just because the repo has its own config.

The **global file ships the model + effort keywords** (`opus`/`sonnet`/`haiku`/
`fable` → `model`, and `minimal`/`low`/`medium`/`high` → `effort`), so those work
everywhere out of the box. Add your own everywhere-aliases there.

Everything is opt-in: no config anywhere → `cc`/`cx` behave as before (native
version shorthands + `c`/`r` still work). No `jq` → bare model aliases and params
go quiet, but the generative `opus4.8`-style shorthand and `c`/`r` still work.

## How a token is interpreted

For each argument, in precedence order:

1. `--` → stop expanding; everything after is passed to the tool **verbatim**.
2. `c` / `r` → `--continue` / `--resume` (native `cc` control shorthands; these
   stay in the shell, not the config — they're claude-only session control).
3. A **key in the merged `.params`** → expanded (below). This now includes the
   global model aliases (`fable`, `opus`, …) and effort aliases (`high`, …), plus
   anything a project adds. Params win over the version rule below.
4. `cc` only: `opus4.8` / `fable5` / `opus48` / … → generative version shorthand
   → `--model claude-<family>-<major>-<minor>` (computed in the shell; dot
   optional). `claude-<id>` → that exact `--model`.
5. Otherwise it passes straight through (a flag, a prompt word, a file, …).

> Name your params so they don't collide with prompt words you actually type
> (especially for `cx`, whose prompt is positional). Anything after `--` is
> always safe.
>
> **Model aliases are claude-oriented.** `fable`/`opus`/… resolve to claude model
> ids; using them with `cx` passes a claude id to codex (`-m claude-…`), which
> codex won't accept. For codex, select models with a raw `-m …` or define your
> own codex-model param. Effort aliases are the opposite — they only materialize
> for `cx` and no-op on `cc` (claude has no effort flag).

## The `params` schema

The file is `params: { <name>: { …intent fields… } }`. The authoritative
definition is [`custom-params.schema.json`](./custom-params.schema.json)
(JSON Schema draft-07); a param may combine any of these fields:

| Field             | Shape                                   | `cc` (claude) becomes            | `cx` (codex) becomes                                    |
|-------------------|-----------------------------------------|----------------------------------|--------------------------------------------------------|
| `description`     | string                                  | (shown in tab-completion)        | (shown in tab-completion)                              |
| `aliases`         | `[string, …]`                           | extra names that resolve to this param (inherit its `harnesses`) | same |
| `harnesses`       | `[claude, codex]` (subset)              | applies only if it lists `claude`| applies only if it lists `codex`                      |
| `mcpServers`      | `{ name: <mcp server def> }`            | merged into one `--mcp-config '{"mcpServers":{…}}'` | `-c mcp_servers.<name>.…` overrides (per field)        |
| `model`           | string                                  | `--model <v>`                    | `-m <v>`                                               |
| `effort`          | `minimal`/`low`/`medium`/`high`         | *(no native flag — ignored)*     | `-c model_reasoning_effort="<v>"`                      |
| `permission-mode` | string (`plan`/`acceptEdits`/…)         | `--permission-mode <v>`          | *(ignored)*                                            |
| `env`             | `{ KEY: VAL }`                          | exported for the run (`env …`)   | exported for the run (`env …`)                         |
| `args`            | `{ cc: [...], cx: [...], both: [...] }` | `both` + `cc` appended literally | `both` + `cx` appended literally                       |

`harnesses` **scopes availability**: omit it and the param applies to both tools;
list `[claude]` and only `cc` recognizes the name (on `cx` it's not a param, so
it passes through), and vice-versa. This is how the shipped model aliases are
kept claude-only where needed and effort aliases codex-only.

An **mcp server def** is the usual MCP shape: `command` + `args` + `env` for
stdio servers, or `type` + `url` for remote (http/sse) servers. Multiple
selected params that each declare `mcpServers` are merged into a single config.

Fields an intent can't express on a given tool are simply skipped there — that's
the point of describing intent instead of raw flags. When you need an exact
flag, use `args` (the escape hatch).

### Precedence

- **Config tiers:** project param beats global param of the same name (whole
  param replaced, not deep-merged).
- **Model on the line:** a generative version shorthand or full id (`opus4.8`,
  `claude-…`) beats a param's `model` (it's appended last, and claude honors the
  last `--model`).
- Later selected params win on `env` key collisions.
- `mcpServers` blocks are additive (merged across selected params), layered on top of
  claude/codex's own configured servers (not `--strict`). Want strict? Add
  `"args": {"cc": ["--strict-mcp-config"]}` to a param.

## Adding a new intent field

The translation lives in `~/.config/zsh/coding-agents.zsh` as three small `jq`
programs (`_CA_ARGS_JQ`, `_CA_ENV_JQ`, `_CA_MCP_JQ`). Add a branch there mapping
your new field to per-tool flags. `cc`/`cx` themselves don't need to change.

## Files

| File | Role |
|------|------|
| `~/.config/zsh/coding-agents.zsh` | engine (`_ca_*`: config discovery, YAML→JSON, merge, intent→flags) **and** the `cc` / `cx` functions that call it |
| `~/.config/zsh/completions.zsh`   | harness-aware tab-completion of param names for `cc` / `cx` |
| `~/.config/coding-agents/custom-params.yaml` | the GLOBAL params (ships model + effort aliases) |
| `~/.config/coding-agents/custom-params.schema.json` | JSON Schema for editor validation |
| `~/.config/coding-agents/custom-params.example.yaml` | annotated template to copy into a project |
| `<project>/.config/coding-agents/custom-params.yaml` | your per-project params |
