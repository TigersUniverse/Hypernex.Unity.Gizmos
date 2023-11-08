-- [[
-- Hypernex.VideoPlayer
-- v1.0.0
-- Written by 200Tigersbloxed
-- ]]
local CONFIG = {
    -- Whether or not to sync the video player over the network
    ["NetworkSync"] = true,
    -- Default value for sharing controls (Should match Server!)
    ["ShareControls"] = true,
    -- A URL to first download for all clients
    ["StartingURL"] = ""
}

-- [[
-- VIDEOPLAYER LOGIC
-- DO NOT EDIT ANYTHING PAST HERE
-- ]]

-- The Controls Canvas
local Controls = item.GetChildByName("Controls")
-- The Background Panel in the Controls Canvas
local Background = Controls.GetChildByName("Background")
-- The TMP_InputField for the Video URL
local URL = Background.GetChildByName("URL")
-- The Button that will load from a URL
local PlayFromURL = Background.GetChildByName("PlayFromURL")
-- The Slider that controls Position
local PositionSlider = Background.GetChildByName("PositionSlider")
-- The Text that displays the minimum and maximum length
local PositionText = Background.GetChildByName("PositionText")
-- The Button that Plays or Pauses
local PlayPause = Background.GetChildByName("PlayPause")
-- The Text for the PlayPause Button
local PlayPauseText = PlayPause.GetChildByName("Text")
-- A Toggle for Looping
local Loop = Background.GetChildByName("Loop")
-- A Toggle for Sharing the VideoPlayer
local Share = Background.GetChildByName("Share")
-- A TMP_InputField for getting a time position
local JumpToText = Background.GetChildByName("JumpToText")
-- A Button for submitting the new position
local JumpToButton = Background.GetChildByName("JumpToButton")
-- A Slider for controlling VideoPlayer Volume
local Volume = Background.GetChildByName("Volume")

-- NetworkSync Cache
local SharingEnabled = CONFIG["ShareControls"]
local gotSync = false
local syncPosition = 0
local isFirstNetLoad = false
local shouldPlayOnSync = true
-- VideoPlayer Cache
local isWorking = false
local toggleFromNet = false
local overrideToggleLoop = false

-- Init Local Components
UI.SetToggle(Loop, Video.IsLooping(item))
if CONFIG["NetworkSync"] then
    UI.SetToggle(Share, SharingEnabled)
else
    Share.Enabled = false
end
UI.RegisterInputFieldVR(URL)

-- Function Tools
local function CanControl()
    if not CONFIG["NetworkSync"] then return true end
    if SharingEnabled then return true end
    return LocalAvatar.IsHost()
end

local function IsTriggerHeld()
    local bindings = Bindings.GetAllPresentBindings()
    if #bindings <= 0 then return false end
    for i = 1, #bindings do
        local binding = bindings[i]
        if Bindings.GetTrigger(binding) >= 0.9 then return true end
    end
    return false
end

local function LoadAndPlayNewVideo(url)
    if CONFIG["NetworkSync"] then
        -- Tell the Server we are switching videos
        NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "load", url})
    else
        -- We do not need to tell the server
        HandleNewVideo(url)
    end
end

local function HandleNewVideo(url)
    if isWorking then return end
    print("Downloading video from "..tostring(url))
    isWorking = true
    Video.Stop(item)
    local getMedia = GetMedia()
    getMedia.url = url
    getMedia.vQuality = VideoQuality.q720
    Cobalt.GetOptions(getMedia, SandboxFunc().SetAction(function(options)
        if options == nil or #options.Options <= 0 then
            UI.SetText(PositionText, "Could not find a video for URL!")
            isWorking = false
            return
        end
        local cobaltOption = options.Options[1]
        UI.SetText(PositionText, "Downloading video...")
        cobaltOption.Download(SandboxFunc().SetAction(function(file) 
            if file == nil then
                UI.SetText(PositionText, "Failed to download video!")
                isWorking = false
                return
            end
            Video.LoadFromCobalt(item, file)
            if (gotSync and shouldPlayOnSync) or not gotSync then Video.Play(item) end
            shouldPlayOnSync = true
            isWorking = false
            if CONFIG["NetworkSync"] then
                if not LocalAvatar.IsHost() then
                    NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "getposition"})
                elseif not isFirstNetLoad and CanControl() then
                    isFirstNetLoad = false
                    NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "position", 0})
                else
                    NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "getposition"})
                end
            end
        end))
    end))
end

local function HandlePausePlay(newValue)
    if not CONFIG["NetworkSync"] then
        if newValue then
            Video.Pause(item)
            UI.SetText(PlayPauseText, "Resume")
        else
            Video.Play(item)
            UI.SetText(PlayPauseText, "Pause")
        end
        return
    end
    local event
    if newValue then event = "play" else event = "pause" end
    NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, event, newValue})
end

local function HandleLoop(newValue)
    if CONFIG["NetworkSync"] then
        NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "loop", newValue})
    else
        Video.SetLoop(item, newValue)
        overrideToggleLoop = true
        UI.SetToggle(Loop, Video.IsLooping(item))
        overrideToggleLoop = false
    end
end

local function HandleSharing(newValue)
    if not CONFIG["NetworkSync"] then return end
    NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "share", newValue})
end

local function HandlePosition(setTime)
    if not CONFIG["NetworkSync"] then
        Video.SetPosition(item, setTime)
        return
    end
    NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "position", setTime})
end

-- https://devforum.roblox.com/t/converting-secs-to-hsec/146352/2
function Format(Int)
	return string.format("%02i", Int)
end

function convertToHMS(Seconds)
	local Minutes = (Seconds - Seconds%60)/60
	Seconds = Seconds - Minutes*60
	local Hours = (Minutes - Minutes%60)/60
	Minutes = Minutes - Hours*60
	return Format(Hours)..":"..Format(Minutes)..":"..Format(Seconds)
end
--

-- Button Handlers
UI.RegisterButtonClick(PlayFromURL, SandboxFunc().SetAction(function()
    -- Do not allow change when working
    if isWorking then return end
    if CONFIG["NetworkSync"] and (SharingEnabled or LocalAvatar.IsHost()) then
        -- There are network sync perms
        LoadAndPlayNewVideo(UI.GetInputFieldText(URL))
    elseif not CONFIG["NetworkSync"] then
        -- There is no NetworkSync
        LoadAndPlayNewVideo(UI.GetInputFieldText(URL))
    end
end))

UI.RegisterButtonClick(PlayPause, SandboxFunc().SetAction(function()
    if isWorking then return end
    if not CanControl() then return end
    HandlePausePlay(not Video.IsPlaying(item))
end))

UI.RegisterToggleValueChanged(Loop, SandboxFunc().SetAction(function()
    if overrideToggleLoop then return end
    if not CanControl() then
        overrideToggleLoop = true
        UI.SetToggle(Loop, Video.IsLooping(item))
        overrideToggleLoop = false
        return
    end
    HandleLoop(not Video.IsLooping(item))
end))

UI.RegisterToggleValueChanged(Share, SandboxFunc().SetAction(function()
    if toggleFromNet then return end
    if not CanControl() then
        UI.SetToggle(Share, SharingEnabled)
        return
    end
    HandleSharing(not SharingEnabled)
    UI.SetToggle(Share, SharingEnabled)
end))

UI.RegisterSliderValueChanged(Volume, SandboxFunc().SetAction(function(value)
    Video.SetVolume(item, value)
end))

UI.RegisterButtonClick(JumpToButton, SandboxFunc().SetAction(function()
    if isWorking or not CanControl() then return end
    HandlePosition(tonumber(UI.GetInputFieldText(JumpToText)))
    UI.SetInputFieldText(JumpToText, "")
end))

-- Runtime Events
Runtime.OnUpdate(SandboxFunc().SetAction(function()
    if isWorking then return end
    if not Video.IsPlaying(item) then return end
    local currentPosition = convertToHMS(Video.GetPosition(item))
    local endPosition = convertToHMS(Video.GetLength(item))
    UI.SetText(PositionText, tostring(currentPosition).." - "..tostring(endPosition))
    UI.SetSliderRange(PositionSlider, 0, Video.GetLength(item))
    UI.SetSlider(PositionSlider, Video.GetPosition(item))
end))

Runtime.RepeatSeconds(SandboxFunc().SetAction(function()
    if not CONFIG["NetworkSync"] then return end
    if not LocalAvatar.IsHost() then return end
    if not Video.IsPlaying(item) then return end
    if isFirstNetLoad then return end
    NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "position_", Video.GetPosition(item)})
end), 3)

-- Network Handling
if not CONFIG["NetworkSync"] then
    if not CONFIG["StartingURL"] == "" then LoadAndPlayNewVideo(CONFIG["StartingURL"]) end
    return
end

Events.Subscribe(ScriptEvent.OnServerNetworkEvent, SandboxFunc().SetAction(function(eventName, eventArgs) 
    -- Do not handle if it is not for us
    if not eventName == "hypernex.videoplayer" then return end
    -- [[
    -- How a message looks
    -- eventArgs[1] - Path
    -- eventArgs[2] - Key
    -- eventArgs[3] - Value  
    -- ]]
    -- Do not handle if this is not the same VideoPlayer
    if not eventArgs[1] == item.Path then return end
    print("Got video message "..tostring(eventName).." from server! To: "..tostring(item.Path))
    -- Load a Video
    if eventArgs[2] == "load" then
        if isWorking then return end
        HandleNewVideo(eventArgs[3])
    end
    if eventArgs[2] == "pause" then
        if isWorking then return end
        Video.Pause(item)
        UI.SetText(PlayPauseText, "Resume")
    end
    if eventArgs[2] == "play" then
        if isWorking then return end
        Video.Play(item)
        UI.SetText(PlayPauseText, "Pause")
    end
    if eventArgs[2] == "time" then
        if isWorking then return end
        Video.SetPosition(item, eventArgs[3])
    end
    if eventArgs[2] == "share" then
        SharingEnabled = eventArgs[3]
        toggleFromNet = true
        UI.SetToggle(Share, SharingEnabled)
        toggleFromNet = false
    end
    if eventArgs[2] == "loop" then Video.SetLoop(item, eventArgs[3]) end
    if eventArgs[2] == "position" then
        if isWorking then return end
        Video.SetPosition(item, tonumber(eventArgs[3]))
    end
    if eventArgs[2] == "get" then
        SharingEnabled = eventArgs[3]
        Video.SetLoop(item, eventArgs[5])
        isFirstNetLoad = tonumber(eventArgs[6]) > 0
        if eventArgs[4] ~= "" then
            shouldPlayOnSync = not eventArgs[7]
            HandleNewVideo(eventArgs[4])
            if eventArgs[7] then
                UI.SetText(PlayPauseText, "Resume")
            else
                UI.SetText(PlayPauseText, "Pause")
            end
        elseif not CONFIG["StartingURL"] == "" and LocalAvatar.IsHost() then
            LoadAndPlayNewVideo(CONFIG["StartingURL"])
        end
    end
    if eventArgs[2] == "getposition" then
        -- TODO: Better Desync prevention
        if isFirstNetLoad and LocalAvatar.IsHost() then NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "position", eventArgs[3]}) end
        -- We now know that there has been some form of initiation with a net load
        isFirstNetLoad = false
        -- We are already loading, cache and wait
        if isWorking then
            gotSync = true
            syncPosition = eventArgs[3]
            return
        end
        gotSync = false
        Video.SetPosition(item, tonumber(eventArgs[3]))
    end
end))

Runtime.RunAfterSeconds(SandboxFunc().SetAction(function()
    NetworkEvent.SendToServer("hypernex.videoplayer", {item.Path, "get"})
end), 5)