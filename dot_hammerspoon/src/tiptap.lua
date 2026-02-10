local ____lualib = require("lualib_bundle")
local __TS__Class = ____lualib.__TS__Class
local __TS__New = ____lualib.__TS__New
local ____exports = {}
--- TipTap class manages trackpad gesture detection and execution
____exports.TipTap = __TS__Class()
local TipTap = ____exports.TipTap
TipTap.name = "TipTap"
function TipTap.prototype.____constructor(self)
    self.holdThreshold = 200
    self.tapTimeout = 800
    self.tapSensitivity = 50
    self.debugMode = false
    self.state = {
        isHolding = false,
        holdStartTime = 0,
        holdStartPos = {x = 0, y = 0},
        lastTapTime = 0,
        tapDownTime = 0,
        tapDownPos = {x = 0, y = 0},
        currentAppBundleID = nil
    }
    self.appActions = {}
    self.defaultActions = {}
    self.eventTap = nil
    self.appWatcher = nil
    self:log("TipTap initialized")
    self:setupDefaultActions()
    self:setupAppActions()
end
function TipTap.prototype.log(self, message, isError)
    if isError == nil then
        isError = false
    end
    if self.debugMode or isError then
        print("[TipTap] " .. message)
    end
end
function TipTap.prototype.setupDefaultActions(self)
    self.defaultActions = {
        tipTapLeft = function()
            self:log("Default left action: cmd+left")
            hs.eventtap.keyStroke({"cmd"}, "left")
        end,
        tipTapRight = function()
            self:log("Default right action: cmd+right")
            hs.eventtap.keyStroke({"cmd"}, "right")
        end
    }
end
function TipTap.prototype.setupAppActions(self)
    local browserTabActions = {
        tipTapLeft = function()
            self:log("Browser: Previous tab")
            hs.eventtap.keyStroke({"cmd", "shift"}, "[")
        end,
        tipTapRight = function()
            self:log("Browser: Next tab")
            hs.eventtap.keyStroke({"cmd", "shift"}, "]")
        end
    }
    self.appActions = {
        ["com.google.Chrome"] = browserTabActions,
        ["com.apple.Safari"] = browserTabActions,
        ["company.thebrowser.Browser"] = browserTabActions,
        ["com.apple.finder"] = {
            tipTapLeft = function()
                self:log("Finder: Back")
                hs.eventtap.keyStroke({"cmd"}, "[")
            end,
            tipTapRight = function()
                self:log("Finder: Forward")
                hs.eventtap.keyStroke({"cmd"}, "]")
            end
        },
        ["com.spotify.client"] = {
            tipTapLeft = function()
                self:log("Spotify: Previous track")
                hs.spotify.previous()
            end,
            tipTapRight = function()
                self:log("Spotify: Next track")
                hs.spotify.next()
            end
        },
        ["com.microsoft.VSCode"] = browserTabActions,
        ["com.apple.Terminal"] = {
            tipTapLeft = function()
                self:log("Terminal: Previous tab")
                hs.eventtap.keyStroke({"cmd", "shift"}, "left")
            end,
            tipTapRight = function()
                self:log("Terminal: Next tab")
                hs.eventtap.keyStroke({"cmd", "shift"}, "right")
            end
        },
        ["com.googlecode.iterm2"] = {
            tipTapLeft = function()
                self:log("iTerm2: Previous tab")
                hs.eventtap.keyStroke({"cmd", "shift"}, "left")
            end,
            tipTapRight = function()
                self:log("iTerm2: Next tab")
                hs.eventtap.keyStroke({"cmd", "shift"}, "right")
            end
        }
    }
end
function TipTap.prototype.configure(self, config)
    if config.holdThreshold ~= nil then
        self.holdThreshold = config.holdThreshold
    end
    if config.tapTimeout ~= nil then
        self.tapTimeout = config.tapTimeout
    end
    if config.tapSensitivity ~= nil then
        self.tapSensitivity = config.tapSensitivity
    end
    if config.debugMode ~= nil then
        self.debugMode = config.debugMode
    end
    if config.appActions then
        self.appActions = config.appActions
    end
    if config.defaultActions then
        self.defaultActions = config.defaultActions
    end
    self:log("TipTap configured with new settings")
    return self
end
function TipTap.prototype.setAppActions(self, bundleID, actions)
    self.appActions[bundleID] = actions
    self:log("Set actions for app: " .. bundleID)
    return self
end
function TipTap.prototype.setDefaultActions(self, actions)
    self.defaultActions = actions
    self:log("Set default actions")
    return self
end
function TipTap.prototype.start(self)
    self:log("Starting TipTap gesture detection")
    self:startAppWatcher()
    self:startEventTap()
    return self
end
function TipTap.prototype.stop(self)
    self:log("Stopping TipTap gesture detection")
    if self.eventTap then
        self.eventTap:stop()
        self.eventTap = nil
    end
    if self.appWatcher then
        self.appWatcher = nil
    end
    return self
end
function TipTap.prototype.startAppWatcher(self)
    self:log("App watcher would be started here (API needs type definitions)")
end
function TipTap.prototype.startEventTap(self)
    self.eventTap = hs.eventtap.new(
        {
            hs.eventtap.event.types.leftMouseDown,
            hs.eventtap.event.types.leftMouseUp,
            hs.eventtap.event.types.rightMouseDown,
            hs.eventtap.event.types.rightMouseUp,
            hs.eventtap.event.types.mouseMoved,
            hs.eventtap.event.types.gesture,
            hs.eventtap.event.types.scrollWheel
        },
        function(event)
            return self:handleTrackpadEvent(event)
        end
    )
    if self.eventTap ~= nil then
        self.eventTap:start()
        self:log("Event tap started successfully")
    else
        self:log("Failed to create event tap", true)
    end
end
function TipTap.prototype.handleTrackpadEvent(self, event)
    local eventType = event:getType()
    local currentTime = hs.timer.secondsSinceEpoch() * 1000
    local location = event:location()
    if eventType == hs.eventtap.event.types.leftMouseDown then
        if not self.state.isHolding then
            self.state.isHolding = true
            self.state.holdStartTime = currentTime
            self.state.holdStartPos = {x = location.x, y = location.y}
            self:log(((">>> Hold established at " .. tostring(location.x)) .. ",") .. tostring(location.y))
        else
            self.state.tapDownTime = currentTime
            self.state.tapDownPos = {x = location.x, y = location.y}
            local deltaX = self.state.tapDownPos.x - self.state.holdStartPos.x
            self:log(((((">>> Second finger down at " .. tostring(location.x)) .. ",") .. tostring(location.y)) .. ", deltaX=") .. tostring(deltaX))
            if currentTime - self.state.lastTapTime > 200 then
                self.state.lastTapTime = currentTime
                if deltaX < 0 then
                    self:log("!!! TIP TAP LEFT DETECTED !!!")
                    self:executeAction("tipTapLeft")
                else
                    self:log("!!! TIP TAP RIGHT DETECTED !!!")
                    self:executeAction("tipTapRight")
                end
            end
        end
    elseif eventType == hs.eventtap.event.types.leftMouseUp then
        if self.state.isHolding then
            if self.state.tapDownTime > 0 and currentTime - self.state.tapDownTime < 500 then
                self:log(">>> Second finger lifted, hold continues")
                self.state.tapDownTime = 0
            else
                local holdDuration = currentTime - self.state.holdStartTime
                self:log((">>> Hold released after " .. tostring(holdDuration)) .. "ms")
                self.state.isHolding = false
                self.state.tapDownTime = 0
            end
        end
    end
    return false
end
function TipTap.prototype.executeAction(self, actionType)
    local actions = nil
    if self.state.currentAppBundleID and self.appActions[self.state.currentAppBundleID] then
        actions = self.appActions[self.state.currentAppBundleID]
        self:log("Using app-specific actions for: " .. self.state.currentAppBundleID)
    else
        actions = self.defaultActions
        self:log("Using default actions")
    end
    if actions and actions[actionType] then
        self:log("Executing " .. actionType)
        actions[actionType](actions)
    else
        self:log("No action defined for: " .. actionType, true)
        hs.alert.show(("TipTap: No " .. actionType) .. " action configured", 0)
    end
end
--- Creates and returns a new TipTap instance
function ____exports.createTipTap()
    return __TS__New(____exports.TipTap)
end
return ____exports
