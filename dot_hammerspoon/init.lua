-- Spotify Controls

local function spotifySkipPosition(seconds)
  local pos = hs.spotify.getPosition()
  local newPos = pos + seconds
  if newPos then
    hs.spotify.setPosition(newPos)
  else
    print("Error newPos: " .. hs.json.encode(newPos))
  end
end

hs.hotkey.bind({"⌥", "⌃"}, "right", function() spotifySkipPosition(20) end)
hs.hotkey.bind({"⌥", "⌃"}, "left", function() spotifySkipPosition(-20) end)
hs.hotkey.bind({"⌥", "⌃", "⇧"}, "right", function() hs.spotify.next() end)
hs.hotkey.bind({"⌥", "⌃", "⇧"}, "left", function() hs.spotify.previous() end)

-- Spotify Playlist Commands (promote/demote)

local activeSpotifyTasks = {}

local function dirExists(path)
  local attributes = hs.fs.attributes(path)
  return (attributes and attributes.mode) == "directory"
end

local function decodeJSONIfString(value)
  if type(value) == "string" then
    local trimmed = string.match(value, "^%s*(.-)%s*$") or ""
    local firstChar = string.sub(trimmed, 1, 1)
    if firstChar == "{" or firstChar == "[" then
      return hs.json.decode(trimmed)
    end

    local lastCandidate = nil
    for line in string.gmatch(trimmed, "[^\r\n]+") do
      local candidate = string.match(line, "^%s*(.-)%s*$") or ""
      local candidateFirstChar = string.sub(candidate, 1, 1)
      if candidateFirstChar == "{" or candidateFirstChar == "[" then
        lastCandidate = candidate
      end
    end

    if lastCandidate then
      return hs.json.decode(lastCandidate)
    end

    return nil
  end

  return value
end

local function normalizeSpotifyResponse(body)
  local decoded = decodeJSONIfString(body or "")

  if type(decoded) ~= "table" then
    return nil
  end

  if decoded.body ~= nil then
    local nested = decodeJSONIfString(decoded.body)
    if type(nested) == "table" then
      return nested
    end
  end

  return decoded
end

local function parseSpotifyBody(body, cmd)
  local payload = normalizeSpotifyResponse(body)

  if payload then
    print("spotify payload " .. hs.json.encode(payload))
  else
    print("spotify payload unavailable")
    return false
  end

  local results = payload.result
  if type(results) ~= "table" then
    if payload.message then
      hs.notify.show("Spotify Command Complete", cmd, tostring(payload.message))
      return true
    end

    return false
  end

  if #results == 0 and results.reason then
    results = {results}
  end

  local displayed = false
  for _, r in ipairs(results) do
    local value = r.value or {}
    local actionType = value.action_type or r.action_type or cmd
    local detail = value.name or r.name or r.reason or value.action_name or payload.message or "Complete"

    hs.notify.show(tostring(actionType) .. " command complete", tostring(actionType), tostring(detail))
    displayed = true
  end

  return displayed
end

local function extractSpotifyError(output)
  if type(output) ~= "string" or output == "" then
    return nil
  end

  local error2JSON = string.match(output, "error2%s+(%b{})")
  if error2JSON then
    local parsed = hs.json.decode(error2JSON)
    if parsed and parsed.body then
      local body = decodeJSONIfString(parsed.body)
      if body and body.error then
        return tostring(body.error)
      end

      return tostring(parsed.body)
    end
  end

  local errorMessage = string.match(output, "errorMessage:%s*'([^']+)'")
  if errorMessage then
    return errorMessage
  end

  errorMessage = string.match(output, 'errorMessage:%s*"([^"]+)"')
  if errorMessage then
    return errorMessage
  end

  if string.find(string.lower(output), "error", 1, true) then
    local rejection = string.match(output, "UnhandledPromiseRejection:%s*(.-)\n")
    if rejection then
      return rejection
    end

    return string.match(output, "([^\n]*error[^\n]*)") or output
  end

  return nil
end

local function spotifyBackendSource(isLocal)
  if isLocal then
    return "spotify-playlist local backend"
  end

  return "spotify-playlist remote endpoint"
end

local function sendSpotifyCommand(cmd)
  local homeDir = "/Users/tal"
  local scriptDir = homeDir .. "/Projects/spotify-playlist"
  local isLocalBackend = dirExists(scriptDir)
  local backendSource = spotifyBackendSource(isLocalBackend)

  print("spotify command [" .. backendSource .. "]: " .. cmd)

  if not isLocalBackend then
    hs.http.asyncGet(
      "https://ovgepxasb9.execute-api.us-east-1.amazonaws.com/dev/spotify-playlist-dev?action=" .. cmd,
      {},
      function(status, body)
        if status ~= 200 then
          hs.notify.show("Spotify Backend Error", backendSource .. " status " .. tostring(status), tostring(body))
          print(backendSource .. " returned HTTP " .. tostring(status) .. ": " .. tostring(body))
          return
        end
        if not parseSpotifyBody(body, cmd) then
          hs.notify.show("Spotify Backend Error", backendSource, "Unparsable response")
          print(backendSource .. " unparsable response: " .. tostring(body))
        end
      end
    )
    return nil
  end

  local taskKey = tostring(hs.timer.absoluteTime())
  local task = hs.task.new(
    "/opt/homebrew/bin/node",
    function(exitCode, stdOut, stdErr)
      activeSpotifyTasks[taskKey] = nil

      if not parseSpotifyBody(stdOut, cmd) then
        local startStr = "body: '"
        local idxStart = string.find(stdOut, startStr, 1, true)
        local idxEnd = string.find(stdOut, "' }\nDone", 1, true)

        if idxStart and idxEnd then
          local jsonText = string.sub(stdOut, idxStart + #startStr, idxEnd - 1)
          local parsed = hs.json.decode(jsonText)
          local first = parsed and parsed.result and parsed.result[1]
          if first then
            hs.notify.show("Spotify Command Complete", cmd, first.reason)
            return
          end
        end

        local extractedError = extractSpotifyError(stdErr) or extractSpotifyError(stdOut)

        if extractedError then
          hs.notify.show("Spotify Backend Error", backendSource .. " (" .. cmd .. ")", extractedError)
          print(backendSource .. " error for " .. cmd .. ": " .. extractedError)
        elseif exitCode and exitCode > 0 then
          hs.notify.show("Spotify Backend Error", backendSource .. " (" .. cmd .. ")", tostring(stdErr))
          print(backendSource .. " stderr for " .. cmd .. ": " .. tostring(stdErr))
        else
          hs.notify.show("Spotify Backend Error", backendSource .. " (" .. cmd .. ")", "Unparsable output")
          print(backendSource .. " unparsable output for " .. cmd .. ": " .. tostring(stdOut))
        end
      end
    end,
    {"./dist/cli.js", cmd}
  )
  task:setWorkingDirectory(scriptDir)
  activeSpotifyTasks[taskKey] = task
  return task
end

hs.hotkey.bind({"⌥", "⌃"}, "up", function()
  hs.alert.show("▲")
  local task = sendSpotifyCommand("promote")
  if task then task:start() end
end)

hs.hotkey.bind({"⌥", "⇧", "⌃"}, "up", function()
  hs.alert.show("▲⥽")
  local task = sendSpotifyCommand("promotes")
  if task then task:start() end
end)

hs.hotkey.bind({"⌥", "⌃"}, "down", function()
  hs.alert.show("▼")
  local task = sendSpotifyCommand("demotes")
  if task then task:start() end
end)

-- Instagram / yt-dlp Downloader
--
-- Driven by Velja: configure a custom destination pointing at
--   hammerspoon://download?url={url}
-- Velja substitutes the URL, Hammerspoon catches it here, downloads with
-- yt-dlp into ~/Downloads, then runs `/sort-videos` via `claude -p`.

local DOWNLOADS_DIR = os.getenv("HOME") .. "/Downloads"
local YT_DLP = "/opt/homebrew/bin/yt-dlp"
local GALLERY_DL = "/opt/homebrew/bin/gallery-dl"
local FFMPEG_DIR = "/opt/homebrew/bin"
-- Persisted Instagram session cookies (Netscape format, exported from Arc).
-- Login-gated reels/posts return an "empty media response" to anonymous
-- requests; passing these fixes the most common failure in the link-accepter
-- log. If the file is missing (never exported, or you cleaned it up) the
-- helpers below just skip --cookies so anonymous downloads still work.
local IG_COOKIES = os.getenv("HOME") .. "/Downloads/.claude/config/instagram-cookies.txt"
-- Transient network blips (DNS not resolving, connection reset) are retried a
-- few times with a simple linear backoff instead of being logged as a hard
-- failure on the first miss.
local MAX_DL_ATTEMPTS = 3
local RETRY_BASE_DELAY = 20 -- seconds; multiplied by the attempt number
-- `zsh -lc` is login-but-not-interactive, so it never sources ~/.zshrc — where
-- the Homebrew + ~/.local/bin PATH lives. Prepend them explicitly so claude and
-- the tools the skill shells out to (whisper-cli, ffmpeg, …) resolve.
local TOOL_PATH = "/opt/homebrew/bin:" .. os.getenv("HOME") .. "/.local/bin"
-- Headless `claude -p` can't answer interactive prompts, so steer the run:
-- pin the model and pre-answer the skill's OCR question with "yes".
local SORT_MODEL = "sonnet"
local OCR_DIRECTIVE = "When the sort-videos skill would ask whether to OCR video frames for on-screen text, always choose yes and proceed with OCR. Never ask about OCR; assume yes and continue."
-- sort-images is pointed at an already-downloaded folder, so its own download
-- step and interactive prompts are skipped. This just bars any stray question
-- in a headless run.
local SORT_IMAGES_DIRECTIVE = "The carousel slides are already downloaded in the folder passed as the argument. Never ask any questions — OCR every slide and file the carousel into the AI Library. Choose yes to anything optional and continue."

local activeDownloadTasks = {}

-- All downloader logging funnels through here so console lines are greppable
-- by the "[ig-dl]" tag.
local function log(fmt, ...)
  local ok, msg = pcall(string.format, fmt, ...)
  print("[ig-dl] " .. (ok and msg or fmt))
end

-- The Hammerspoon console clears on every config reload, so failures get
-- *also* appended to a persistent file with a timestamp. `tail -f` this to
-- watch link-accepter failures, or grep it after a download silently no-ops.
local LINK_LOG_FILE = os.getenv("HOME") .. "/Downloads/hammerspoon-link-accepter.log"

local function logFail(fmt, ...)
  local ok, msg = pcall(string.format, fmt, ...)
  msg = ok and msg or fmt
  log("%s", msg) -- still surface it in the console alongside everything else
  local f = io.open(LINK_LOG_FILE, "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. msg .. "\n")
    f:close()
  else
    print("[ig-dl] could not open log file " .. LINK_LOG_FILE)
  end
end

-- Trim/whitespace-collapse a captured stream for one-line console logging.
local function snippet(s, max)
  s = string.gsub(tostring(s or ""), "%s+", " ")
  s = string.match(s, "^%s*(.-)%s*$") or s
  if #s > (max or 300) then
    s = string.sub(s, 1, max or 300) .. "…"
  end
  return s
end

local function trackTask(prefix, task)
  local key = prefix .. "-" .. tostring(hs.timer.absoluteTime())
  activeDownloadTasks[key] = task
  return key
end

local function fileExists(path)
  local f = io.open(path, "r")
  if f then f:close(); return true end
  return false
end

local function isInstagramURL(url)
  return string.match(url, "instagram%.com/") ~= nil
end

-- yt-dlp/gallery-dl cookie flag for Instagram URLs, but only when the export
-- actually exists — passing --cookies with a missing file just errors out.
local function cookieArgsFor(url)
  if isInstagramURL(url) and fileExists(IG_COOKIES) then
    return {"--cookies", IG_COOKIES}
  end
  return {}
end

-- Distinguish "the network hiccuped" (worth retrying) from "the post is gated /
-- gone" (retrying won't help — log it). Matched against yt-dlp/gallery-dl
-- stderr.
local function isTransientNetworkError(stderr)
  local s = string.lower(tostring(stderr or ""))
  local patterns = {
    "failed to resolve",              -- DNS down (the exact log signature)
    "temporary failure in name resolution",
    "getaddrinfo",
    "nodename nor servname",
    "connection reset",
    "connection refused",
    "connection timed out",
    "timed out",
    "network is unreachable",
    "remote end closed connection",
    "read timed out",
  }
  for _, p in ipairs(patterns) do
    if string.find(s, p, 1, true) then return true end
  end
  return false
end

-- Actually launch the sort-videos skill headlessly. Uses a login shell so
-- claude (and the tools the skill shells out to — whisper-cpp, ffmpeg, etc.)
-- resolve against the full interactive PATH. Unattended, so permission prompts
-- are bypassed; dial this back if you'd rather review each run. `onDone` is
-- invoked (success or failure) so the queue can advance to the next request.
local function executeSortVideos(targetDir, onDone)
  hs.notify.show("Sorting videos…", "", "Running /sort-videos in ~/Downloads")

  -- Default scans ~/Downloads; an explicit folder (e.g. a /p/ post that turned
  -- out to be a video) is passed straight through to the skill.
  local skillArg = targetDir and ("/sort-videos " .. targetDir) or "/sort-videos"
  local shellCmd = "export PATH=\"" .. TOOL_PATH .. ":$PATH\"; cd " .. DOWNLOADS_DIR
    .. " && claude -p '" .. skillArg .. "'"
    .. " --model " .. SORT_MODEL
    .. " --append-system-prompt '" .. OCR_DIRECTIVE .. "'"
    .. " --dangerously-skip-permissions"
  log("sort-videos: launching /bin/zsh -lc %q", shellCmd)

  local key
  local task = hs.task.new(
    "/bin/zsh",
    function(exitCode, stdOut, stdErr)
      activeDownloadTasks[key] = nil
      log("sort-videos: exited code=%s", tostring(exitCode))
      if stdOut and stdOut ~= "" then log("sort-videos: stdout: %s", snippet(stdOut, 500)) end
      if exitCode == 0 then
        hs.notify.show("Videos sorted ✅", "", "/sort-videos finished")
        log("sort-videos: done")
      else
        hs.notify.show("sort-videos failed", "exit " .. tostring(exitCode), snippet(stdErr, 200))
        log("sort-videos: FAILED stderr: %s", snippet(stdErr, 500))
      end
      if onDone then onDone() end
    end,
    {"-lc", shellCmd}
  )
  key = trackTask("sort", task)
  local started = task:start()
  log("sort-videos: task %s start=%s pid=%s", key, tostring(started), tostring(task:pid()))
end

-- A queue of downloads tends to finish in a burst — yt-dlp drains its list and
-- every completed download wants to kick off a sort run. Firing N identical
-- `claude -p '/sort-videos'` processes at the same instant is wasteful and they
-- trample each other in ~/Downloads. So coalesce: each request just (re)arms a
-- debounce timer, and only once downloads have been quiet for SORT_DEBOUNCE
-- seconds does a single run fire. Runs are also serialized — never two
-- sort-videos in flight at once — and identical targets dedupe to one run.
local SORT_DEBOUNCE = 8  -- seconds of quiet before a sort kicks off
local DEFAULT_SORT_KEY = "*default*"  -- stands in for the no-arg ~/Downloads scan
local pendingSortDirs = {}  -- set: key -> targetDir string, or false for the default scan
local sortVideosRunning = false

-- Pop one pending request and run it, chaining to the next when it finishes.
-- No-ops while a run is already in flight (the finishing run re-drains).
local function drainSortQueue()
  if sortVideosRunning then return end
  local key = next(pendingSortDirs)
  if not key then return end
  local targetDir = pendingSortDirs[key]
  pendingSortDirs[key] = nil
  sortVideosRunning = true
  executeSortVideos(targetDir or nil, function()
    sortVideosRunning = false
    drainSortQueue()
  end)
end

local sortVideosTimer = hs.timer.delayed.new(SORT_DEBOUNCE, drainSortQueue)

-- Public entrypoint (same name/signature as before): request a sort-videos run.
-- Coalesces a burst of requests within the debounce window into a single run
-- per distinct target.
local function runSortVideos(targetDir)
  local key = targetDir or DEFAULT_SORT_KEY
  pendingSortDirs[key] = targetDir or false
  log("sort-videos: queued %s (debounce %ss)", key, tostring(SORT_DEBOUNCE))
  sortVideosTimer:start()  -- (re)start the countdown; settles after the burst
end

-- Did gallery-dl actually pull a video? An Instagram /p/ post can be a single
-- reel-style clip rather than an image carousel; if so we hand it to
-- sort-videos instead of sort-images.
local function folderHasVideo(dir)
  local ok, iter = pcall(hs.fs.dir, dir)
  if not ok then return false end
  for f in iter do
    local lower = string.lower(f)
    if string.match(lower, "%.mp4$") or string.match(lower, "%.webm$")
       or string.match(lower, "%.mkv$") or string.match(lower, "%.mov$") then
      return true
    end
  end
  return false
end

-- Run the sort-images skill headlessly against a specific folder of slides.
-- Pointing it at the folder makes the skill skip its own download + prompts.
local function runSortImages(targetDir)
  hs.notify.show("Sorting carousel… 🎠", "", "Running /sort-images")

  local shellCmd = "export PATH=\"" .. TOOL_PATH .. ":$PATH\"; cd " .. DOWNLOADS_DIR
    .. " && claude -p '/sort-images " .. targetDir .. "'"
    .. " --model " .. SORT_MODEL
    .. " --append-system-prompt '" .. SORT_IMAGES_DIRECTIVE .. "'"
    .. " --dangerously-skip-permissions"
  log("sort-images: launching /bin/zsh -lc %q", shellCmd)

  local key
  local task = hs.task.new(
    "/bin/zsh",
    function(exitCode, stdOut, stdErr)
      activeDownloadTasks[key] = nil
      log("sort-images: exited code=%s", tostring(exitCode))
      if stdOut and stdOut ~= "" then log("sort-images: stdout: %s", snippet(stdOut, 500)) end
      if exitCode == 0 then
        hs.notify.show("Carousel sorted ✅", "", "/sort-images finished")
        log("sort-images: done")
      else
        hs.notify.show("sort-images failed", "exit " .. tostring(exitCode), snippet(stdErr, 200))
        log("sort-images: FAILED stderr: %s", snippet(stdErr, 500))
      end
    end,
    {"-lc", shellCmd}
  )
  key = trackTask("sortimg", task)
  local started = task:start()
  log("sort-images: task %s start=%s pid=%s", key, tostring(started), tostring(task:pid()))
end

-- gallery-dl downloads every carousel slide into ~/Downloads/<shortcode>_carousel/,
-- then routes to sort-images (or sort-videos if the post was actually a video).
local function downloadCarousel(url, attempt)
  attempt = attempt or 1
  local shortcode = string.match(url, "instagram%.com/p/([%w_%-]+)")
    or tostring(hs.timer.absoluteTime())
  local carouselDir = DOWNLOADS_DIR .. "/" .. shortcode .. "_carousel"
  hs.notify.show("Downloading carousel… ⬇️🎠", "", url)

  -- `-D` flattens slides into one dir; `--write-metadata` saves the caption
  -- sidecar the skill reads. Cookies (below) authenticate login-gated posts.
  local args = {
    "-D", carouselDir,
    "--write-metadata",
  }
  for _, a in ipairs(cookieArgsFor(url)) do table.insert(args, a) end
  table.insert(args, url)
  log("gallery-dl: downloading %s -> %s (attempt %s/%s)",
    url, carouselDir, tostring(attempt), tostring(MAX_DL_ATTEMPTS))
  log("gallery-dl: argv: %s %s", GALLERY_DL, table.concat(args, " "))

  local key
  local task = hs.task.new(
    GALLERY_DL,
    function(exitCode, stdOut, stdErr)
      activeDownloadTasks[key] = nil
      log("gallery-dl: exited code=%s for %s", tostring(exitCode), url)
      if stdOut and stdOut ~= "" then log("gallery-dl: stdout: %s", snippet(stdOut, 500)) end
      if exitCode == 0 then
        hs.notify.show("Carousel downloaded 🎉", "", url)
        if folderHasVideo(carouselDir) then
          log("gallery-dl: pulled a video, routing to sort-videos")
          runSortVideos(carouselDir)
        else
          log("gallery-dl: done, kicking off sort-images")
          runSortImages(carouselDir)
        end
      elseif isTransientNetworkError(stdErr) and attempt < MAX_DL_ATTEMPTS then
        local delay = RETRY_BASE_DELAY * attempt
        log("gallery-dl: transient network error, retrying %s/%s in %ss for %s",
          tostring(attempt + 1), tostring(MAX_DL_ATTEMPTS), tostring(delay), url)
        hs.timer.doAfter(delay, function() downloadCarousel(url, attempt + 1) end)
      else
        hs.notify.show("Carousel download failed", "gallery-dl exit " .. tostring(exitCode), snippet(stdErr, 200))
        logFail("gallery-dl: FAILED exit=%s url=%s stderr: %s", tostring(exitCode), url, snippet(stdErr, 500))
      end
    end,
    args
  )
  key = trackTask("gdl", task)
  local started = task:start()
  log("gallery-dl: task %s start=%s pid=%s", key, tostring(started), tostring(task:pid()))
end

local function downloadURL(url, attempt)
  attempt = attempt or 1
  hs.notify.show("Downloading… ⬇️", "", url)

  local args = {
    "--no-playlist",
    "--ffmpeg-location", FFMPEG_DIR,
    "--paths", DOWNLOADS_DIR,
    "-o", "%(uploader)s - %(title).80B [%(id)s].%(ext)s",
    -- Ride out flaky connections rather than failing on the first blip.
    "--retries", "5",
    "--fragment-retries", "5",
    "--extractor-retries", "3",
    "--socket-timeout", "30",
  }
  -- Cookies for login-gated Instagram (no-op for other hosts / missing file).
  for _, a in ipairs(cookieArgsFor(url)) do table.insert(args, a) end
  table.insert(args, url)
  log("yt-dlp: downloading %s (attempt %s/%s)", url, tostring(attempt), tostring(MAX_DL_ATTEMPTS))
  log("yt-dlp: argv: %s %s", YT_DLP, table.concat(args, " "))

  local key
  local task = hs.task.new(
    YT_DLP,
    function(exitCode, stdOut, stdErr)
      activeDownloadTasks[key] = nil
      log("yt-dlp: exited code=%s for %s", tostring(exitCode), url)
      if stdOut and stdOut ~= "" then log("yt-dlp: stdout: %s", snippet(stdOut, 500)) end
      if exitCode == 0 then
        hs.notify.show("Download complete 🎉", "", url)
        log("yt-dlp: done, kicking off sort-videos")
        runSortVideos()
      elseif isTransientNetworkError(stdErr) and attempt < MAX_DL_ATTEMPTS then
        local delay = RETRY_BASE_DELAY * attempt
        log("yt-dlp: transient network error, retrying %s/%s in %ss for %s",
          tostring(attempt + 1), tostring(MAX_DL_ATTEMPTS), tostring(delay), url)
        hs.timer.doAfter(delay, function() downloadURL(url, attempt + 1) end)
      else
        hs.notify.show("Download failed", "yt-dlp exit " .. tostring(exitCode), snippet(stdErr, 200))
        logFail("yt-dlp: FAILED exit=%s url=%s stderr: %s", tostring(exitCode), url, snippet(stdErr, 500))
      end
    end,
    args
  )
  key = trackTask("dl", task)
  local started = task:start()
  log("yt-dlp: task %s start=%s pid=%s", key, tostring(started), tostring(task:pid()))
end

-- Video hosts we hand to the yt-dlp lane. Instagram reels/tv plus the common
-- yt-dlp-supported sites. Instagram /p/ photo posts are handled separately
-- (carousel lane); anything matching none of these is opened in Arc instead.
local VIDEO_URL_PATTERNS = {
  "instagram%.com/reel",
  "instagram%.com/tv/",
  "youtube%.com/",
  "youtu%.be/",
  "tiktok%.com/",
  "twitter%.com/",
  "x%.com/",
  "vimeo%.com/",
  "reddit%.com/",
}

local ARC_BUNDLE_ID = "company.thebrowser.Browser"

local function matchesAny(url, patterns)
  for _, pat in ipairs(patterns) do
    if string.match(url, pat) then return true end
  end
  return false
end

-- Fallback for URLs we don't download: hand them back to Arc to open normally.
local function openInArc(url)
  log("dispatch: no download match → opening in Arc: %s", url)
  local ok = hs.urlevent.openURLWithBundle(url, ARC_BUNDLE_ID)
  if not ok then
    logFail("dispatch: openURLWithBundle failed for %s, falling back to `open -a Arc`", url)
    hs.execute("open -a Arc '" .. string.gsub(url, "'", "'\\''") .. "'")
  end
  hs.notify.show("Opened in Arc 🌐", "", url)
end

-- Branch by URL shape:
--   instagram.com/p/      → image carousel → gallery-dl → sort-images
--   instagram reels/tv + common video hosts → yt-dlp → sort-videos
--   anything else         → kicked back out to Arc to open normally
local function dispatchURL(url)
  if string.match(url, "instagram%.com/p/") then
    log("dispatch: /p/ post → gallery-dl carousel lane")
    downloadCarousel(url)
  elseif matchesAny(url, VIDEO_URL_PATTERNS) then
    log("dispatch: → yt-dlp video lane")
    downloadURL(url)
  else
    openInArc(url)
  end
end

-- hammerspoon://download?url=<percent-encoded-url>
hs.urlevent.bind("download", function(eventName, params, senderPID, fullURL)
  log("event '%s' from pid=%s fullURL=%s", tostring(eventName), tostring(senderPID), tostring(fullURL))

  local url = params and params.url
  -- Fallback: if the incoming URL carried its own (unencoded) query string,
  -- hs.urlevent may split it across params — recover the raw tail instead.
  if (not url or url == "") and fullURL then
    url = string.match(fullURL, "url=(.+)$")
    log("event: params.url empty, recovered url from raw tail: %s", tostring(url))
  end

  if not url or url == "" then
    hs.notify.show("Download", "No URL", "hammerspoon://download received no url param")
    logFail("event: no url param, ignoring (fullURL=%s)", tostring(fullURL))
    return
  end

  log("event: resolved url=%s", url)
  dispatchURL(url)
end)

-- Velja can also route the *raw* http(s):// URL to Hammerspoon as an app
-- destination (rather than rewriting it to hammerspoon://download?url=…). In
-- that case the URL lands here on the http callback instead of the bind above.
hs.urlevent.httpCallback = function(scheme, host, params, fullURL)
  log("httpCallback scheme=%s host=%s fullURL=%s", tostring(scheme), tostring(host), tostring(fullURL))
  if not fullURL or fullURL == "" then
    hs.notify.show("Download", "No URL", "http callback received no URL")
    logFail("httpCallback: no URL, ignoring (fullURL=%s)", tostring(fullURL))
    return
  end
  dispatchURL(fullURL)
end

-- Config File Watcher

local function setupConfigFileWatcher()
  local configDir = os.getenv("HOME") .. "/.hammerspoon/"
  local watcher = hs.pathwatcher.new(configDir, function(changedFiles)
    for _, file in ipairs(changedFiles) do
      if string.sub(file, -4) == ".lua" then
        print("Lua config file changed: " .. file)
        hs.notify.show("Hammerspoon", "Configuration reloaded", "Config file change detected")
        hs.reload()
        return
      end
    end
  end)
  if watcher then
    watcher:start()
  end
end

setupConfigFileWatcher()
