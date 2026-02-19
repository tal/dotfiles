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

local function dirExists(path)
  local attributes = hs.fs.attributes(path)
  return (attributes and attributes.mode) == "directory"
end

local function parseSpotifyBody(body, cmd)
  local bodyJSON = hs.json.decode(body or "")
  if bodyJSON then
    print("body " .. hs.json.encode(bodyJSON))
  else
    print("nil body")
  end
  if bodyJSON and bodyJSON.result then
    for _, r in ipairs(bodyJSON.result) do
      local actionType = (r.value and r.value.action_type) or cmd
      local reason = (r.value and r.value.name) or r.reason
      hs.notify.show(tostring(actionType) .. " command complete", actionType, reason)
    end
  end
end

local function sendSpotifyCommand(cmd)
  local homeDir = "/Users/tal"
  local scriptDir = homeDir .. "/Projects/spotify-playlist"

  if not dirExists(scriptDir) then
    hs.http.asyncGet(
      "https://ovgepxasb9.execute-api.us-east-1.amazonaws.com/dev/spotify-playlist-dev?action=" .. cmd,
      {},
      function(status, body)
        if status ~= 200 then
          hs.notify.show("Spotify Command Error", "Status not 200, " .. tostring(status), body)
          return
        end
        parseSpotifyBody(body, cmd)
      end
    )
    return nil
  end

  print("spotify command: " .. cmd)
  local task = hs.task.new(
    "/opt/homebrew/bin/node",
    function(exitCode, stdOut, stdErr)
      local result = hs.json.decode(stdOut)
      local body = hs.json.decode(result and result.body or "")

      if body and body.result then
        parseSpotifyBody(result.body, cmd)
      else
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

        if exitCode and exitCode > 0 then
          hs.notify.show("Spotify Command Error", cmd, stdErr)
          print(stdErr)
        else
          hs.notify.show("Spotify Command", "unparsable", stdOut)
        end
      end
    end,
    {"./dist/cli.js", cmd}
  )
  task:setWorkingDirectory(scriptDir)
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
