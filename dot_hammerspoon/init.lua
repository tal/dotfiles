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
