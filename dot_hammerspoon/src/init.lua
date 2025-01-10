local ____lualib = require("lualib_bundle")
local __TS__StringSubstring = ____lualib.__TS__StringSubstring
BaseDefinitions = {
    a = {desc = "Messages", key = "a", appName = "Messages.app", subInvocations = {w = {desc = "WhatsApp", key = "w", appName = "WhatsApp.app"}}},
    c = {desc = "Chat", key = "c", appName = "Slack.app"},
    e = {desc = "Email", key = "e", appName = "Shortwave.app"},
    m = {desc = "Spotify", key = "m", appName = "Spotify.app"},
    t = {desc = "Tasks", key = "m", appName = "Things3.app"},
    n = {desc = "Notes", key = "n", appName = "Craft.app"},
    w = {desc = "Arc", key = "w", appName = "Arc.app", subInvocations = {s = {desc = "Safari", key = "s", appName = "Safari.app"}}}
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
                if definition.appName then
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
function sendSpotifyCommand(cmd)
    local homeDir = "/Users/tal"
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
            if body then
                print("body " .. hs.json.encode(body or "{}"))
            else
                print("nil  body")
            end
            if body and body.result then
                for ____, r in ipairs(body.result) do
                    local ____opt_4 = r.value
                    if ____opt_4 ~= nil then
                        ____opt_4 = ____opt_4.action_type
                    end
                    local ____opt_4_6 = ____opt_4
                    if ____opt_4_6 == nil then
                        ____opt_4_6 = cmd
                    end
                    local actionType = ____opt_4_6
                    local ____r_value_name_7 = r.value.name
                    if ____r_value_name_7 == nil then
                        ____r_value_name_7 = r.reason
                    end
                    local reason = ____r_value_name_7
                    hs.notify.show(
                        tostring(actionType) .. " command complete",
                        actionType,
                        reason
                    )
                end
                return
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
                hs.notify.show("Spotify Command", "unparseable", stdOut)
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
        sendSpotifyCommand("promote"):start()
    end
)
hs.hotkey.bind(
    {"⌥", "⇧", "⌃"},
    "up",
    nil,
    function()
        hs.alert.show("▲⥽")
        sendSpotifyCommand("promotes"):start()
    end
)
hs.hotkey.bind(
    {"⌥", "⌃"},
    "down",
    nil,
    function()
        hs.alert.show("▼")
        sendSpotifyCommand("demotes"):start()
    end
)
