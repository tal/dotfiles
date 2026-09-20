# Custom-params engine for the `cc` (claude) and `cx` (codex) functions.
#
# A project can carry a file at
#     <project>/.config/coding-agents/custom-params.json
# defining named "params" -- intent bundles you tack onto a run:
#     cc fable beeper-mcp        # fable model + Beeper MCP, just this run
#     cx think staging           # high effort + staging env, just this run
#
# You describe intent ("make this MCP available", "use this model", "crank
# effort") and this engine materializes it into whatever flags claude vs codex
# actually want. Unknown tokens pass straight through, and anything after `--`
# is passed literally with no expansion. See ~/.config/coding-agents/README.md.
#
# This file defines both the `_ca_*` helpers AND the user-facing `cc` / `cx`
# functions that call into them (at the bottom of this file); completions live
# in completions.zsh. jq does all the parsing/translation -- if jq is missing
# the whole thing degrades to "every token passes through unchanged".

# Where per-directory config lives, and the basenames accepted (first found wins
# in a given dir). YAML is primary; .yml and legacy .json also work.
_CA_CONFIG_DIR=".config/coding-agents"
_CA_CONFIG_BASENAMES=(custom-params.yaml custom-params.yml custom-params.json)

# Print the config file inside <dir> ($1), if any (first accepted basename wins).
_ca_config_in() {
  local base
  for base in $_CA_CONFIG_BASENAMES; do
    [[ -f "$1/$_CA_CONFIG_DIR/$base" ]] && { print -r -- "$1/$_CA_CONFIG_DIR/$base"; return 0; }
  done
  return 1
}

# Print every config file that applies at $PWD, shallowest first (the global
# ~/.config/coding-agents base) and deepest last (the nearest project file) --
# i.e. the order to merge them in. One path per line; nothing if none.
_ca_config_paths() {
  local -a up
  local dir="$PWD" hit
  while [[ -n "$dir" ]]; do
    hit="$(_ca_config_in "$dir")" && up+=("$hit")
    [[ "$dir" == "/" || "$dir" == "$HOME" ]] && break
    dir="${dir:h}"
  done
  # Ensure the global/home config is the base even when $PWD is outside $HOME
  # (there the walk stops at / and never visits $HOME).
  local ghit
  ghit="$(_ca_config_in "$HOME")" && [[ ${up[(Ie)$ghit]} -eq 0 ]] && up+=("$ghit")
  # `up` is deepest-first; emit shallowest-first so the merge lets deeper win.
  local i
  for (( i = ${#up}; i >= 1; i-- )); do print -r -- "${up[i]}"; done
}

# Convert a YAML (or JSON) config file <path> ($1) to JSON on stdout, using
# whatever parser is available: yq, then macOS ruby (psych), then python3+pyyaml.
# Non-zero if none work or the file can't be parsed. (JSON is valid YAML, so the
# same path handles legacy .json files.)
_ca_yaml_to_json() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  if command -v yq >/dev/null 2>&1; then
    yq -o=json '.' "$f" 2>/dev/null && return 0
  fi
  if command -v ruby >/dev/null 2>&1; then
    ruby -ryaml -rjson -e 'print JSON.generate(YAML.load(ARGF.read))' "$f" 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import yaml,json,sys; json.dump(yaml.safe_load(open(sys.argv[1])), sys.stdout)' "$f" 2>/dev/null && return 0
  fi
  return 1
}

# Print the MERGED params document for $PWD: the global/home config as the base
# with each more-specific project config layered on top. On a same-named param
# the nearer (deeper) file wins wholesale (shallow, param-level replace). Empty
# output + non-zero when no config exists or jq is unavailable.
_ca_merged() {
  command -v jq >/dev/null 2>&1 || return 1
  local -a files=(${(f)"$(_ca_config_paths)"})
  (( ${#files} )) || return 1
  local f json all=''
  for f in "${files[@]}"; do
    json="$(_ca_yaml_to_json "$f")" || continue
    all+="$json"$'\n'
  done
  [[ -n "$all" ]] || return 1
  print -r -- "$all" | jq -s 'reduce .[] as $c ({params: {}}; .params = (.params + ($c.params // {})))' 2>/dev/null
}

# A param applies to a harness when it has no `harnesses` key (applies to all)
# or its `harnesses` list includes that harness. cc => "claude", cx => "codex".
# The programs below carry this as a jq `def applies` so they can be single-
# quoted (no zsh interpolation); the harness is passed to jq as --arg h ("" = all).
#
# _CA_KEYS_JQ: emit "<token>\t<canonical param name>" for every recognized token
# -- each param's own name plus every entry in its `aliases` list -- filtered to
# harness $h. Lets us recognize a bare token and resolve an alias to its param.
_CA_KEYS_JQ='
def applies: ($h == "") or (.value.harnesses == null) or ((.value.harnesses // []) | index($h));
(.params // {}) | to_entries[]
| select(applies)
| .key as $k
| ([$k] + (.value.aliases // []))[]
| . + "\t" + $k
'

# _CA_NAMES_JQ: emit "<name>:<description>" for completion, filtered to harness
# $h, one line per param name and per alias (aliases marked).
_CA_NAMES_JQ='
def applies: ($h == "") or (.value.harnesses == null) or ((.value.harnesses // []) | index($h));
def clean: gsub("[\n:]"; " ");
(.params // {}) | to_entries[]
| select(applies)
| .key as $k | ((.value.description // "custom param")) as $d
| ($k + ":" + ($d | clean)),
  ((.value.aliases // [])[] | . + ":" + (($d + " (alias of " + $k + ")") | clean))
'

# Print "<token>\t<canonical>" lines (param names + aliases) applicable to
# harness <harness> ($2; "" = all) in merged JSON <json> ($1). Recognizes tokens.
_ca_param_map() {
  command -v jq >/dev/null 2>&1 || return 1
  jq -r --arg h "${2:-}" "$_CA_KEYS_JQ" <<< "$1" 2>/dev/null
}

# Print "name:description" lines (incl. aliases) for params in merged JSON <json>
# ($1), filtered to harness <harness> ($2; empty = all). Used by completion.
_ca_param_names() {
  command -v jq >/dev/null 2>&1 || return 1
  jq -r --arg h "${2:-}" "$_CA_NAMES_JQ" <<< "$1" 2>/dev/null
}

# jq program: turn selected params into a flat stream of tool-specific argv
# tokens. $tool is "cc" or "cx"; $ARGS.positional holds the selected param
# names. `cc` MCP is handled separately (merged --mcp-config); everything else
# -- model, effort, permission-mode, raw per-tool args, and `cx` MCP -- is here.
_CA_ARGS_JQ='
def kv($k; $v): ["-c", ($k + "=" + ($v | tojson))];
.params as $p
| [ $ARGS.positional[] as $n | ($p[$n] // {})
    | (
        (if has("model")
           then (if $tool == "cc" then ["--model", .model] else ["-m", .model] end)
           else [] end)
      + (if has("effort")
           then (if $tool == "cx" then kv("model_reasoning_effort"; .effort) else [] end)
           else [] end)
      + (if has("permission-mode")
           then (if $tool == "cc" then ["--permission-mode", .["permission-mode"]] else [] end)
           else [] end)
      + ((.args.both // []) + (.args[$tool] // []))
      + (if ($tool == "cx" and has("mcpServers"))
           then ( [ .mcpServers | to_entries[] as $s
                    | (if ($s.value.command != null) then kv("mcp_servers." + $s.key + ".command"; $s.value.command) else [] end)
                    + (if ($s.value.args    != null) then kv("mcp_servers." + $s.key + ".args";    $s.value.args)    else [] end)
                    + (if ($s.value.url     != null) then kv("mcp_servers." + $s.key + ".url";     $s.value.url)     else [] end)
                    + (($s.value.env // {}) | to_entries | map(kv("mcp_servers." + $s.key + ".env." + .key; .value)) | add // [])
                  ] | add // [] )
           else [] end)
      )
  ]
| add // []
| .[]
'

# jq program: env vars (KEY=VAL) contributed by the selected params, for either
# tool. Later params win on key collisions (jq keeps them in order; the shell
# `env` prefix applies them left-to-right).
_CA_ENV_JQ='
.params as $p
| [ $ARGS.positional[] as $n | ($p[$n].env // {}) | to_entries[] | (.key + "=" + (.value | tostring)) ]
| .[]
'

# jq program: merge the .mcpServers objects of the selected params into one
# {"mcpServers": {...}} document (for claude --mcp-config). claude keeps each
# server's `type` (e.g. http); codex materialization above drops it since codex
# infers transport from `url`. Empty output when no selected param has servers.
_CA_MCP_JQ='
.params as $p
| [ $ARGS.positional[] | $p[.].mcpServers // {} ] | add // {}
| if (. | length) > 0 then {mcpServers: .} else empty end
'

# Materialize selected params for a tool. Populates two globals the caller
# reads: `_ca_args` (extra argv) and `_ca_env` (KEY=VAL assignments).
#   $1 = config path (may be empty)   $2 = tool (cc|cx)   $3.. = param names
_ca_materialize() {
  local merged="$1" tool="$2"; shift 2
  local -a names=("$@")
  _ca_args=(); _ca_env=()
  [[ -n "$merged" ]] || return 0
  (( ${#names} )) || return 0
  command -v jq >/dev/null 2>&1 || return 0

  local tok
  while IFS= read -r -d '' tok; do
    _ca_args+=("$tok")
  done < <(jq --raw-output0 --arg tool "$tool" "$_CA_ARGS_JQ" --args "${names[@]}" <<< "$merged")

  while IFS= read -r -d '' tok; do
    _ca_env+=("$tok")
  done < <(jq --raw-output0 "$_CA_ENV_JQ" --args "${names[@]}" <<< "$merged")

  if [[ "$tool" == "cc" ]]; then
    local mcp_json
    mcp_json=$(jq -c "$_CA_MCP_JQ" --args "${names[@]}" <<< "$merged")
    [[ -n "$mcp_json" ]] && _ca_args+=(--mcp-config "$mcp_json")
  fi
}

# ---------------------------------------------------------------------------
# User-facing functions: `cc` (claude) and `cx` (codex). They call the `_ca_*`
# helpers above; harness-aware tab-completion for both lives in completions.zsh.
# ---------------------------------------------------------------------------

# cc function: claude wrapper with composable custom params.
#
# Order doesn't matter. Tokens are, in precedence:
#   --            everything after is passed to claude verbatim
#   c / r         --continue / --resume (native control shorthands)
#   <custom param> any name defined in the merged custom-params.json -- this now
#                 includes the model aliases (fable/opus/sonnet/haiku) and effort
#                 aliases (minimal/low/medium/high) shipped in the global
#                 ~/.config/coding-agents/custom-params.json, plus anything a
#                 project adds. Params merge global<-project (see the
#                 `_ca_merged` helper above) and win over the version rule.
#   opus48 / fable5.1 / ...  generative version shorthand -> --model claude-<...>
#   claude-<id>   an explicit full model id
#   anything else passed straight through (flags, prompt, files)
# Example:  cc fable beeper-mcp   (global `fable` alias + a project's beeper-mcp).
cc() {
  local args=()
  local model=''
  local passthrough=0
  local merged
  local -a ca_params
  typeset -A ca_resolve
  merged="$(_ca_merged 2>/dev/null)" || merged=''
  # Recognized tokens applicable to the claude harness -- each param name and
  # each of its aliases -- mapped to the canonical param name.
  if [[ -n "$merged" ]]; then
    local _tok _canon
    while IFS=$'\t' read -r _tok _canon; do ca_resolve[$_tok]="$_canon"; done \
      < <(_ca_param_map "$merged" claude)
  fi

  for arg in "$@"; do
    if (( passthrough )); then
      args+=("$arg")
      continue
    fi
    case "$arg" in
      --)
        passthrough=1
        ;;
      c)
        args+=(--continue)
        ;;
      r)
        args+=(--resume)
        ;;
      *)
        if [[ -n "${ca_resolve[$arg]}" ]]; then
          # A defined custom param or one of its aliases -> its canonical name.
          ca_params+=("${ca_resolve[$arg]}")
        elif [[ "$arg" == (opus|sonnet|haiku|fable)[0-9]* ]]; then
          # Versioned generative shorthand: opus4.8, opus48, fable5, fable5.0, ...
          # The dot is optional -- "opus48" is treated the same as "opus4.8".
          if [[ "$arg" =~ ^(opus|sonnet|haiku|fable)([0-9]+)(\.[0-9]+)?$ ]]; then
            local family="$match[1]" verpart="$match[2]" dotpart="$match[3]"
            local major minor
            if [[ -n "$dotpart" ]]; then
              major="$verpart"
              minor="${dotpart#.}"
            elif (( ${#verpart} > 1 )); then
              major="${verpart[1]}"
              minor="${verpart[2,-1]}"
            else
              major="$verpart"
              minor=""
            fi
            if [[ -n "$minor" ]]; then
              model="claude-${family}-${major}-${minor}"
            else
              model="claude-${family}-${major}"
            fi
          else
            args+=("$arg")
          fi
        elif [[ "$arg" == claude-* ]]; then
          model="$arg"
        else
          args+=("$arg")
        fi
        ;;
    esac
  done

  # Expand any custom params into extra args (+ env) for claude.
  local -a _ca_args _ca_env
  _ca_materialize "$merged" cc "${ca_params[@]}"

  local -a final
  final=("${args[@]}" "${_ca_args[@]}")
  # An explicit versioned/full model on the command line wins over a param's
  # model, so append it last (claude honors the last --model).
  [[ -n "$model" ]] && final+=(--model "$model")

  local -a envprefix
  (( ${#_ca_env} )) && envprefix=(env "${_ca_env[@]}")

  "${envprefix[@]}" claude --allow-dangerously-skip-permissions --chrome "${final[@]}"
}

# cx function: codex counterpart to cc. Always runs with --yolo
# (alias for --dangerously-bypass-approvals-and-sandbox). Supports the same
# merged custom params as cc (see the `_ca_merged` helper above) -- e.g. the
# global effort aliases materialize as `-c model_reasoning_effort=...`. Every
# other argument -- including the prompt -- is passed straight through to codex,
# and anything after a literal `--` is passed with no expansion.
cx() {
  local arg passthrough=0 merged
  local -a args ca_params
  typeset -A ca_resolve
  merged="$(_ca_merged 2>/dev/null)" || merged=''
  # Recognized tokens applicable to the codex harness -- names + aliases -- each
  # mapped to its canonical param name.
  if [[ -n "$merged" ]]; then
    local _tok _canon
    while IFS=$'\t' read -r _tok _canon; do ca_resolve[$_tok]="$_canon"; done \
      < <(_ca_param_map "$merged" codex)
  fi

  for arg in "$@"; do
    if (( passthrough )); then
      args+=("$arg")
      continue
    fi
    case "$arg" in
      --)
        passthrough=1
        ;;
      *)
        if [[ -n "${ca_resolve[$arg]}" ]]; then
          ca_params+=("${ca_resolve[$arg]}")
        else
          args+=("$arg")
        fi
        ;;
    esac
  done

  local -a _ca_args _ca_env
  _ca_materialize "$merged" cx "${ca_params[@]}"

  local -a envprefix
  (( ${#_ca_env} )) && envprefix=(env "${_ca_env[@]}")

  "${envprefix[@]}" codex --yolo "${_ca_args[@]}" "${args[@]}"
}
