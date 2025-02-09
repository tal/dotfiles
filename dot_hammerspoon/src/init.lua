local ____lualib = require("lualib_bundle")
local __TS__StringSubstring = ____lualib.__TS__StringSubstring
BaseDefinitions = {
    a = {desc = "Messages", key = "a", appName = "Messages.app", subInvocations = {w = {desc = "WhatsApp", key = "w", appName = "WhatsApp.app"}, a = {desc = "Messages", key = "a", appName = "Messages.app"}}},
    c = {desc = "Chat", key = "c", appName = "Slack.app"},
    e = {desc = "Email", key = "e", appName = "Shortwave.app"},
    f = {desc = "Calendar", key = "f", appName = "Fantastical.app", subInvocations = {g = {desc = "Google Calendar", key = "g", appName = "Google Calendar.app"}, f = {desc = "Fantastical", key = "f", appName = "Fantastical.app"}}},
    m = {desc = "Spotify", key = "m", appName = "Spotify.app"},
    n = {desc = "Notes", key = "n", appName = "Craft.app"},
    t = {desc = "Tasks", key = "m", appName = "Things3.app"},
    w = {desc = "Web", key = "w", subInvocations = {w = {desc = "Arc", key = "w", appName = "Arc.app"}, s = {desc = "Safari", key = "s", appName = "Safari.app"}}}
}
currentDefinitions = BaseDefinitions
invocationTap = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown},
    function(ev)
        if ev and ev:getType() == hs.eventtap.event.types.keyDown then
            local key = hs.keycodes.map[ev:getKeyCode()]
            if key == "z" and ev:getFlags().ctrl then
                currentDefinitions = BaseDefinitions
                return true
            end
            local definition = currentDefinitions[key]
            if definition ~= nil then
                hs.alert.closeAll()
                hs.alert.show((key .. " - ") .. definition.desc, 0.5)
                if definition.subInvocations then
                    currentDefinitions = definition.subInvocations
                    return true
                end
                if definition.appName then
                    print("launching " .. definition.appName)
                    hs.application.launchOrFocus(definition.appName)
                end
            end
            invocationTap:stop()
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
        hs.alert.show("⌃z", 0.5)
        if not invocationTap:isEnabled() then
            invocationTap:start()
            hs.timer.doAfter(
                1,
                function()
                    invocationTap:stop()
                end
            )
        end
    end
)
currentDefinitions = BaseDefinitions
invocationTap:stop()
ctrlZHotkey:enable()
hs.hotkey.bind(
    {"⌃"},
    "`",
    nil,
    function()
        hs.application.launchOrFocus("Warp.app")
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
                local ____opt_4 = r.value
                if ____opt_4 ~= nil then
                    ____opt_4 = ____opt_4.action_type
                end
                local ____opt_4_6 = ____opt_4
                if ____opt_4_6 == nil then
                    ____opt_4_6 = cmd
                end
                local actionType = ____opt_4_6
                local ____opt_7 = r.value
                if ____opt_7 ~= nil then
                    ____opt_7 = ____opt_7.name
                end
                local ____opt_7_9 = ____opt_7
                if ____opt_7_9 == nil then
                    ____opt_7_9 = r.reason
                end
                local reason = ____opt_7_9
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
        local ____opt_16 = sendSpotifyCommand("promote")
        if ____opt_16 ~= nil then
            ____opt_16:start()
        end
    end
)
hs.hotkey.bind(
    {"⌥", "⇧", "⌃"},
    "up",
    nil,
    function()
        hs.alert.show("▲⥽")
        local ____opt_18 = sendSpotifyCommand("promotes")
        if ____opt_18 ~= nil then
            ____opt_18:start()
        end
    end
)
hs.hotkey.bind(
    {"⌥", "⌃"},
    "down",
    nil,
    function()
        hs.alert.show("▼")
        local ____opt_20 = sendSpotifyCommand("demotes")
        if ____opt_20 ~= nil then
            ____opt_20:start()
        end
    end
)
