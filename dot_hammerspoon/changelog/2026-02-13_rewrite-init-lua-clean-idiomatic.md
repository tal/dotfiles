# Rewrite init.lua in clean idiomatic Lua

## Summary

Rewrote `init.lua` from transpiled TypeScript-to-Lua (TSTL) output to clean, hand-written idiomatic Lua.

## Changes

### Removed
- **Ctrl+Z app launcher** — entire feature removed (canvas UI, key definitions, eventtap, hotkey)
- **`lualib_bundle.lua`** — 83KB TSTL runtime bundle deleted

### Kept (rewritten)
- **Spotify skip position** — Opt+Ctrl+Right/Left to skip ±20 seconds
- **Spotify next/prev track** — Opt+Ctrl+Shift+Right/Left
- **Spotify promote/demote** — Opt+Ctrl+Up/Down and Opt+Shift+Ctrl+Up for playlist management via local `spotify-playlist` Node.js project or API fallback
- **Config file watcher** — auto-reloads Hammerspoon when `.lua` files change

### Cleanup details
- Replaced `__TS__StringEndsWith` with `string.sub(file, -4) == ".lua"`
- Replaced `__TS__StringSubstring` with `string.sub`
- Replaced `__TS__ArraySome` with a simple `for` loop
- Replaced TSTL optional chaining patterns with standard `if x then x.y end`
- All functions declared `local`
- Removed excessive `pcall` wrapping
- Extracted `parseSpotifyBody` as a shared local function (was inline closure `parseBody`)
- Reduced from ~558 lines to ~135 lines
