-- [[
-- Hypernex.VideoPlayer
-- v1.2.0
-- Written by 200Tigersbloxed
-- ]]

local CONFIG = {
    -- Default value for sharing controls (Should match Client!)
    ["ShareControls"] = true
}

-- [[
-- VIDEOPLAYER LOGIC
-- DO NOT EDIT ANYTHING PAST HERE
-- ]]

local videoPlayerCache = {}

-- Network Handling
Events.Subscribe(ScriptEvent.OnUserNetworkEvent, SandboxFunc().SetAction(function(userid, eventName, eventArgs)
    -- Do not handle if it is not for us
    if not eventName == "hypernex.videoplayer" then return end
    if eventArgs[2] == "get" then
        -- Return current info
        if videoPlayerCache[eventArgs[1]] ~= nil then
            NetworkEvent.SendToClient(userid, "hypernex.videoplayer", {
                eventArgs[1],
                "get",
                videoPlayerCache[eventArgs[1]]["ShareControls"],
                videoPlayerCache[eventArgs[1]]["url"],
                videoPlayerCache[eventArgs[1]]["loop"],
                videoPlayerCache[eventArgs[1]]["position"],
                videoPlayerCache[eventArgs[1]]["pause"]
            })
        end
    elseif eventArgs[2] == "getposition" then
        if videoPlayerCache[eventArgs[1]] ~= nil then
            NetworkEvent.SendToClient(userid, "hypernex.videoplayer", {
                eventArgs[1],
                "getposition",
                videoPlayerCache[eventArgs[1]]["position"]
            })
        end
    else
        -- Route user update
        if eventArgs[1] ~= nil then 
            if videoPlayerCache[eventArgs[1]] == nil then
                videoPlayerCache[eventArgs[1]] = {
                    ["ShareControls"] = CONFIG["ShareControls"],
                    ["url"] = "",
                    ["loop"] = true,
                    ["position"] = 0,
                    ["pause"] = false
                }
            end
            if not videoPlayerCache[eventArgs[1]]["ShareControls"] and not userid == Instance.HostId then return end
            if eventArgs[2] == "share" then videoPlayerCache[eventArgs[1]]["ShareControls"] = not videoPlayerCache[eventArgs[1]]["ShareControls"] end
            if eventArgs[2] == "load" then videoPlayerCache[eventArgs[1]]["url"] = eventArgs[3] end
            if eventArgs[2] == "play" then videoPlayerCache[eventArgs[1]]["pause"] = false end
            if eventArgs[2] == "pause" then videoPlayerCache[eventArgs[1]]["pause"] = true end
            if eventArgs[2] == "loop" then videoPlayerCache[eventArgs[1]]["loop"] = eventArgs[3] end
            if eventArgs[2] == "position_" and userid == Instance.HostId then videoPlayerCache[eventArgs[1]]["position"] = eventArgs[3] end
            NetworkEvent.SendToAllClients("hypernex.videoplayer", {eventArgs[1], eventArgs[2], eventArgs[3]})
        end
    end
end))