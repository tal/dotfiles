local ____lualib = require("lualib_bundle")
local __TS__StringSplit = ____lualib.__TS__StringSplit
local __TS__StringSubstring = ____lualib.__TS__StringSubstring
local __TS__StringEndsWith = ____lualib.__TS__StringEndsWith
local __TS__ArraySome = ____lualib.__TS__ArraySome
local __TS__ObjectKeys = ____lualib.__TS__ObjectKeys
local __TS__ArraySort = ____lualib.__TS__ArraySort
local __TS__ArrayForEach = ____lualib.__TS__ArrayForEach
--- Creates and displays a canvas showing available keys and their actions
-- 
-- @param definitions The current set of key definitions to display
function showKeysCanvas(definitions)
    if keysCanvas then
        keysCanvas:delete()
        keysCanvas = nil
    end
    local screenWidth = 1280
    local screenHeight = 800
    do
        local function ____catch(____error)
            print("Error getting screen dimensions: " .. tostring(____error))
        end
        local ____try, ____hasReturned = pcall(function()
            local ____opt_26 = hs.window.focusedWindow()
            local ____opt_24 = ____opt_26 and ____opt_26:screen()
            local frameSize = ____opt_24 and ____opt_24.frame()
            if frameSize and frameSize.w and frameSize.h then
                screenWidth = frameSize.w
                screenHeight = frameSize.h
                print((("Got screen dimensions from focused window : " .. tostring(screenWidth)) .. "x") .. tostring(screenHeight))
            else
                do
                    local function ____catch(innerError)
                        print("Error with allScreens approach: " .. tostring(innerError))
                    end
                    local ____try, ____hasReturned = pcall(function()
                        local allScreens = hs.screen.allScreens()
                        if allScreens and #allScreens > 0 then
                            local firstScreen = allScreens[1]
                            if firstScreen ~= nil then
                                local frame = firstScreen.frame()
                                if frame and frame.w and frame.h then
                                    screenWidth = frame.w
                                    screenHeight = frame.h
                                    print((("Got screen dimensions from allScreens[0]: " .. tostring(screenWidth)) .. "x") .. tostring(screenHeight))
                                end
                            end
                        end
                    end)
                    if not ____try then
                        ____catch(____hasReturned)
                    end
                end
            end
        end)
        if not ____try then
            ____catch(____hasReturned)
        end
    end
    local keys = __TS__ArraySort(__TS__ObjectKeys(definitions))
    local keysPerRow = 4
    local rowHeight = 30
    local padding = 15
    local headerHeight = 30
    local numRows = math.ceil(#keys / keysPerRow)
    local canvasHeight = math.max(50, headerHeight + numRows * rowHeight + padding * 2)
    local canvasWidth = math.max(400, screenWidth * 0.8)
    local canvasX = math.max(0, (screenWidth - canvasWidth) / 2)
    local canvasY = math.max(0, screenHeight - canvasHeight - 20)
    print((((((("Creating canvas with dimensions: x=" .. tostring(canvasX)) .. ", y=") .. tostring(canvasY)) .. ", w=") .. tostring(canvasWidth)) .. ", h=") .. tostring(canvasHeight))
    do
        local function ____catch(____error)
            print("Error creating canvas: " .. tostring(____error))
            return true
        end
        local ____try, ____hasReturned, ____returnValue = pcall(function()
            keysCanvas = hs.canvas.new({x = canvasX, y = canvasY, w = canvasWidth, h = canvasHeight})
        end)
        if not ____try then
            ____hasReturned, ____returnValue = ____catch(____hasReturned)
        end
        if ____hasReturned then
            return ____returnValue
        end
    end
    if not keysCanvas then
        print("Error: Canvas creation failed")
        return
    end
    do
        local function ____catch(____error)
            print("Error adding background: " .. tostring(____error))
            return true
        end
        local ____try, ____hasReturned, ____returnValue = pcall(function()
            keysCanvas:appendElements({{
                type = "rectangle",
                action = "fill",
                fillColor = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.85},
                roundedRectRadii = {xRadius = 12, yRadius = 12},
                frame = {x = 0, y = 0, w = canvasWidth, h = canvasHeight}
            }})
        end)
        if not ____try then
            ____hasReturned, ____returnValue = ____catch(____hasReturned)
        end
        if ____hasReturned then
            return ____returnValue
        end
    end
    local titleText = "Available Shortcuts"
    if #navigationPath > 0 then
        titleText = table.concat(navigationPath, " → ")
    end
    do
        local function ____catch(____error)
            print("Error adding title: " .. tostring(____error))
        end
        local ____try, ____hasReturned = pcall(function()
            keysCanvas:appendElements({{
                type = "text",
                text = titleText,
                textColor = {red = 1, green = 1, blue = 1, alpha = 1},
                textSize = 18,
                textAlignment = "center",
                frame = {x = 0, y = padding, w = canvasWidth, h = headerHeight}
            }})
        end)
        if not ____try then
            ____catch(____hasReturned)
        end
    end
    local cellWidth = canvasWidth / keysPerRow
    do
        local function ____catch(keysError)
            print("Error in keys rendering loop: " .. tostring(keysError))
        end
        local ____try, ____hasReturned = pcall(function()
            __TS__ArrayForEach(
                keys,
                function(____, key, index)
                    local def = definitions[key]
                    local row = math.floor(index / keysPerRow)
                    local col = index % keysPerRow
                    local x = col * cellWidth
                    local y = headerHeight + padding + row * rowHeight
                    do
                        local function ____catch(itemError)
                            print((("Error adding key " .. key) .. ": ") .. tostring(itemError))
                        end
                        local ____try, ____hasReturned = pcall(function()
                            keysCanvas:appendElements({{
                                type = "rectangle",
                                action = "fill",
                                fillColor = {red = 0.3, green = 0.3, blue = 0.3, alpha = 0.7},
                                roundedRectRadii = {xRadius = 6, yRadius = 6},
                                frame = {x = x + 10, y = y + 2, w = 26, h = 26}
                            }, {
                                type = "text",
                                text = key,
                                textColor = {red = 1, green = 1, blue = 1, alpha = 1},
                                textSize = 16,
                                textAlignment = "center",
                                frame = {x = x + 10, y = y + 2, w = 26, h = 26}
                            }, {
                                type = "text",
                                text = def.desc,
                                textColor = {red = 0.9, green = 0.9, blue = 0.9, alpha = 1},
                                textSize = 14,
                                textAlignment = "left",
                                frame = {x = x + 45, y = y, w = cellWidth - 50, h = 30}
                            }})
                        end)
                        if not ____try then
                            ____catch(____hasReturned)
                        end
                    end
                    if def.appName and keysCanvas then
                        do
                            local function ____catch(iconError)
                                print((("Error adding app icon for " .. key) .. ": ") .. tostring(iconError))
                            end
                            local ____try, ____hasReturned = pcall(function()
                                keysCanvas:appendElements({{
                                    type = "circle",
                                    action = "fill",
                                    fillColor = {red = 0.2, green = 0.6, blue = 0.9, alpha = 0.8},
                                    radius = 3,
                                    center = {x = x + 38, y = y + 15}
                                }})
                            end)
                            if not ____try then
                                ____catch(____hasReturned)
                            end
                        end
                    end
                    if def.subInvocations and keysCanvas then
                        do
                            local function ____catch(submenuError)
                                print((("Error adding submenu icon for " .. key) .. ": ") .. tostring(submenuError))
                            end
                            local ____try, ____hasReturned = pcall(function()
                                keysCanvas:appendElements({{
                                    type = "text",
                                    text = "▶",
                                    textColor = {red = 0.7, green = 0.7, blue = 0.7, alpha = 1},
                                    textSize = 12,
                                    frame = {x = x + cellWidth - 20, y = y + 2, w = 15, h = 26}
                                }})
                            end)
                            if not ____try then
                                ____catch(____hasReturned)
                            end
                        end
                    end
                end
            )
        end)
        if not ____try then
            ____catch(____hasReturned)
        end
    end
    if #navigationPath > 0 and keysCanvas then
        do
            local function ____catch(escapeError)
                print("Error adding escape instruction: " .. tostring(escapeError))
            end
            local ____try, ____hasReturned = pcall(function()
                keysCanvas:appendElements({{
                    type = "text",
                    text = "Press ESC to go back",
                    textColor = {red = 0.7, green = 0.7, blue = 0.7, alpha = 0.9},
                    textSize = 12,
                    textAlignment = "center",
                    frame = {x = 0, y = canvasHeight - 20, w = canvasWidth, h = 20}
                }})
            end)
            if not ____try then
                ____catch(____hasReturned)
            end
        end
    end
    do
        local function ____catch(____error)
            print("Error showing canvas: " .. tostring(____error))
        end
        local ____try, ____hasReturned = pcall(function()
            keysCanvas:level(25)
            keysCanvas:show()
        end)
        if not ____try then
            ____catch(____hasReturned)
        end
    end
end
--- Hides the keys canvas if it's currently displayed
function hideKeysCanvas()
    if keysCanvas then
        keysCanvas:delete()
        keysCanvas = nil
    end
end
keysCanvas = nil
navigationPath = {}
BaseDefinitions = {
    a = {desc = "Messages", key = "a", appName = "Messages.app", subInvocations = {w = {desc = "WhatsApp", key = "w", appName = "WhatsApp.app"}, a = {desc = "Messages", key = "a", appName = "Messages.app"}}},
    c = {desc = "Chat", key = "c", appName = "Slack.app"},
    e = {desc = "Email", key = "e", appName = "Shortwave.app"},
    f = {desc = "Calendar", key = "f", appName = "Fantastical.app", subInvocations = {g = {desc = "Google Calendar", key = "g", appName = "Google Calendar.app"}, f = {desc = "Fantastical", key = "f", appName = "Fantastical.app"}}},
    m = {desc = "Spotify", key = "m", appName = "Spotify.app"},
    n = {desc = "Notes", key = "n", appName = "Craft.app"},
    t = {desc = "Tasks", key = "m", appName = "Things3.app"},
    w = {desc = "Web", key = "w", subInvocations = {w = {desc = "Arc", key = "w", appName = "Arc.app"}, s = {desc = "Safari", key = "s", appName = "Safari.app"}, c = {desc = "Chrome", key = "c", appName = "Google Chrome.app"}}}
}
currentDefinitions = BaseDefinitions
invocationTap = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown},
    function(ev)
        if ev and ev:getType() == hs.eventtap.event.types.keyDown then
            local key = hs.keycodes.map[ev:getKeyCode()]
            if key == "z" and ev:getFlags().ctrl then
                currentDefinitions = BaseDefinitions
                navigationPath = {}
                return true
            end
            if key == "escape" and #navigationPath > 0 then
                table.remove(navigationPath)
                local current = BaseDefinitions
                for ____, segment in ipairs(navigationPath) do
                    local parts = __TS__StringSplit(segment, ":")
                    local navKey = parts[1]
                    local ____opt_0 = current[navKey]
                    if ____opt_0 and ____opt_0.subInvocations then
                        current = current[navKey].subInvocations
                    end
                end
                currentDefinitions = current
                showKeysCanvas(currentDefinitions)
                return true
            end
            local definition = currentDefinitions[key]
            if definition ~= nil then
                hs.alert.closeAll()
                hs.alert.show((key .. " - ") .. definition.desc, 0.5)
                if definition.subInvocations then
                    navigationPath[#navigationPath + 1] = (key .. ":") .. definition.desc
                    currentDefinitions = definition.subInvocations
                    showKeysCanvas(currentDefinitions)
                    return true
                end
                if definition.appName then
                    print("launching " .. definition.appName)
                    hs.application.launchOrFocus(definition.appName)
                end
                hideKeysCanvas()
                invocationTap:stop()
                return true
            end
            invocationTap:stop()
            hideKeysCanvas()
            return true
        end
        return false
    end
)
ctrlZHotkey = hs.hotkey.new(
    {"⌃"},
    "z",
    nil,
    function()
        currentDefinitions = BaseDefinitions
        navigationPath = {}
        hs.alert.show("⌃z", 0.5)
        showKeysCanvas(currentDefinitions)
        if not invocationTap:isEnabled() then
            invocationTap:start()
            hs.timer.doAfter(
                5,
                function()
                    if invocationTap:isEnabled() then
                        invocationTap:stop()
                        hideKeysCanvas()
                    end
                end
            )
        end
    end
)
currentDefinitions = BaseDefinitions
invocationTap:stop()
hs.hotkey.bind(
    {"⌃"},
    "`",
    nil,
    function()
        hs.application.launchOrFocus("Warp.app")
    end
)
hs.hotkey.bind(
    {"⌃"},
    "1",
    nil,
    function()
        hs.application.launchOrFocus("Visual Studio Code.app")
    end
)
hs.hotkey.bind(
    {"⌃"},
    "2",
    nil,
    function()
        hs.application.launchOrFocus("Arc.app")
    end
)
hs.hotkey.bind(
    {"⌃"},
    "3",
    nil,
    function()
        hs.application.launchOrFocus("Xcode.app")
    end
)
function spotifySkipPosition(seconds)
    local pos = hs.spotify.getPosition()
    local newPos = tonumber(pos + seconds)
    if newPos then
        hs.spotify.setPosition(newPos)
    else
        print("Error newPos: " .. hs.json.encode(newPos))
    end
end
hs.hotkey.bind(
    {"⌥", "⌃"},
    "right",
    nil,
    function()
        spotifySkipPosition(20)
    end
)
hs.hotkey.bind(
    {"⌥", "⌃"},
    "left",
    nil,
    function()
        spotifySkipPosition(-20)
    end
)
hs.hotkey.bind(
    {"⌥", "⌃", "⇧"},
    "right",
    nil,
    function()
        hs.spotify.next()
    end
)
hs.hotkey.bind(
    {"⌥", "⌃", "⇧"},
    "left",
    nil,
    function()
        hs.spotify.previous()
    end
)
function dirExists(path)
    local attributes = hs.fs.attributes(path)
    return (attributes and attributes.mode) == "directory"
end
function sendSpotifyCommand(cmd)
    local homeDir = "/Users/tal"
    local scriptDir = homeDir .. "/Projects/spotify-playlist"
    local function parseBody(body)
        local bodyJSON = hs.json.decode(body or "")
        if bodyJSON then
            print("body " .. hs.json.encode(bodyJSON or "{}"))
        else
            print("nil  body")
        end
        if bodyJSON and bodyJSON.result then
            for ____, r in ipairs(bodyJSON.result) do
                local ____opt_6 = r.value
                if ____opt_6 ~= nil then
                    ____opt_6 = ____opt_6.action_type
                end
                local ____opt_6_8 = ____opt_6
                if ____opt_6_8 == nil then
                    ____opt_6_8 = cmd
                end
                local actionType = ____opt_6_8
                local ____opt_9 = r.value
                if ____opt_9 ~= nil then
                    ____opt_9 = ____opt_9.name
                end
                local ____opt_9_11 = ____opt_9
                if ____opt_9_11 == nil then
                    ____opt_9_11 = r.reason
                end
                local reason = ____opt_9_11
                hs.notify.show(
                    tostring(actionType) .. " command complete",
                    actionType,
                    reason
                )
            end
            return
        end
    end
    if not dirExists(scriptDir) then
        hs.http.asyncGet(
            "https://ovgepxasb9.execute-api.us-east-1.amazonaws.com/dev/spotify-playlist-dev?action=" .. cmd,
            {},
            function(status, body, headers)
                if status ~= 200 then
                    return hs.notify.show(
                        "Spotify Command Error",
                        "Status not 200, " .. tostring(status),
                        body
                    )
                end
                parseBody(body)
            end
        )
        return
    end
    local command = "/opt/homebrew/bin/node"
    local args = {"./dist/cli.js", cmd}
    print("spotify command: " .. cmd)
    local task = hs.task.new(
        command,
        function(exitCode, stdOut, stdErr)
            local startStr = "body: '"
            local idxStart = (string.find(stdOut, startStr, nil, true) or 0) - 1
            local idxEnd = (string.find(stdOut, "' }\nDone", nil, true) or 0) - 1
            local result = hs.json.decode(stdOut)
            local body = hs.json.decode(result and result.body or "")
            if body and body.result then
                parseBody(result and result.body)
            elseif idxStart >= 0 and idxEnd >= 0 then
                local jsonText = __TS__StringSubstring(stdOut, idxStart + #startStr, idxEnd)
                local result = hs.json.decode(jsonText)
                local first = result.result and result.result[1]
                print(hs.json.encode({first = first}))
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
        end,
        args
    )
    task:setWorkingDirectory(homeDir .. "/Projects/spotify-playlist")
    return task
end
hs.hotkey.bind(
    {"⌥", "⌃"},
    "up",
    nil,
    function()
        hs.alert.show("▲")
        local ____opt_18 = sendSpotifyCommand("promote")
        if ____opt_18 ~= nil then
            ____opt_18:start()
        end
    end
)
hs.hotkey.bind(
    {"⌥", "⇧", "⌃"},
    "up",
    nil,
    function()
        hs.alert.show("▲⥽")
        local ____opt_20 = sendSpotifyCommand("promotes")
        if ____opt_20 ~= nil then
            ____opt_20:start()
        end
    end
)
hs.hotkey.bind(
    {"⌥", "⌃"},
    "down",
    nil,
    function()
        hs.alert.show("▼")
        local ____opt_22 = sendSpotifyCommand("demotes")
        if ____opt_22 ~= nil then
            ____opt_22:start()
        end
    end
)
--- Sets up a file watcher that automatically reloads Hammerspoon config
-- when any Lua file in the Hammerspoon config directory changes
function setupConfigFileWatcher()
    local configDir = os.getenv("HOME") .. "/.hammerspoon/"
    print("Setting up config file watcher for " .. configDir)
    local watcher = hs.pathwatcher.new(
        configDir,
        function(changedFiles, flagTables)
            local shouldReload = __TS__ArraySome(
                changedFiles,
                function(____, file)
                    local isLuaFile = __TS__StringEndsWith(file, ".lua")
                    if isLuaFile then
                        print("Lua config file changed: " .. file)
                        return true
                    end
                    return false
                end
            )
            if shouldReload then
                print("Reloading Hammerspoon configuration...")
                local notification = hs.notify.show("Hammerspoon", "Configuration reloaded", "Config file change detected")
                notification:withdrawAfter(2)
                hs.reload()
            end
        end
    )
    if watcher then
        watcher:start()
        print("Config file watcher started")
    else
        print("Error: Could not create config file watcher")
    end
end
setupConfigFileWatcher()
