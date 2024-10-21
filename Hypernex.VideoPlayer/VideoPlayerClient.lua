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

local Players = instance.GetHandler("Players")
local Bindings = instance.GetHandler("Bindings")
local Network = instance.GetHandler("Network")
local Runtime = instance.GetHandler("Runtime")
local Events = instance.GetHandler("Events")

local LocalPlayer = Players.LocalPlayer

local URLTextInput = URL.GetComponent("textinput")
local PlayFromURLButton = PlayFromURL.GetComponent("button")
local PositionSliders = PositionSlider.GetComponent("slider")
local ShareToggle = Share.GetComponent("toggle")
local PositionTextLabel = PositionText.GetComponent("text")
local PlayPauseButton = PlayPause.GetComponent("button")
local PlayPauseTextLabel = PlayPauseText.GetComponent("text")
local LoopToggle = Loop.GetComponent("toggle")
local ShareToggle = Share.GetComponent("toggle")
local JumpToTextInput = JumpToText.GetComponent("textinput")
local JumpToButtonb = JumpToButton.GetComponent("button")
local VolumeSlider = Volume.GetComponent("slider")
local VideoPlayer = item.GetComponent("video")

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
LoopToggle.SetToggle(VideoPlayer.IsLooping())
if CONFIG["NetworkSync"] then
    ShareToggle.SetToggle(SharingEnabled)
else
    Share.Enabled = false
end
URLTextInput.RegisterInputFieldVR()
JumpToTextInput.RegisterInputFieldVR()

-- Function Tools
local function CanControl()
    if not CONFIG["NetworkSync"] then return true end
    if SharingEnabled then return true end
    return LocalPlayer.IsHost
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
        Network.SendToServer("hypernex.videoplayer", {item.Path, "load", url})
    else
        -- We do not need to tell the server
        HandleNewVideo(url)
    end
end

local function HandleNewVideo(url)
    if isWorking then return end
    print("Downloading video from "..tostring(url))
    isWorking = true
    VideoPlayer.Stop()
    local getMedia = GetMedia()
    getMedia.url = url
    getMedia.vQuality = VideoQuality.q720
    Cobalt.GetOptions(getMedia, SandboxFunc().SetAction(function(options)
        if options == nil or #options.Options <= 0 then
            PositionTextLabel.SetText("Could not find a video for URL!")
            isWorking = false
            return
        end
        local cobaltOption = options.Options[1]
        PositionTextLabel.SetText("Downloading video...")
        cobaltOption.Download(SandboxFunc().SetAction(function(file) 
            if file == nil then
                PositionTextLabel.SetText("Failed to download video!")
                isWorking = false
                return
            end
            VideoPlayer.LoadFromCobalt(file)
            if (gotSync and shouldPlayOnSync) or not gotSync then VideoPlayer.Play() end
            shouldPlayOnSync = true
            isWorking = false
            if CONFIG["NetworkSync"] then
                if not LocalPlayer.IsHost then
                    Network.SendToServer("hypernex.videoplayer", {item.Path, "getposition"})
                elseif not isFirstNetLoad and CanControl() then
                    isFirstNetLoad = false
                    Network.SendToServer("hypernex.videoplayer", {item.Path, "position", 0})
                else
                    Network.SendToServer("hypernex.videoplayer", {item.Path, "getposition"})
                end
            end
        end))
    end))
end

local function HandlePausePlay(newValue)
    if not CONFIG["NetworkSync"] then
        if newValue then
            VideoPlayer.Pause()
            PlayPauseTextLabel.SetText("Resume")
        else
            VideoPlayer.Play()
            PlayPauseTextLabel.SetText("Pause")
        end
        return
    end
    local event
    if newValue then event = "play" else event = "pause" end
    Network.SendToServer("hypernex.videoplayer", {item.Path, event, newValue})
end

local function HandleLoop(newValue)
    if CONFIG["NetworkSync"] then
        Network.SendToServer("hypernex.videoplayer", {item.Path, "loop", newValue})
    else
        VideoPlayer.SetLoop()
        overrideToggleLoop = true
        LoopToggle.SetToggle(VideoPlayer.IsLooping())
        overrideToggleLoop = false
    end
end

local function HandleSharing(newValue)
    if not CONFIG["NetworkSync"] then return end
    Network.SendToServer("hypernex.videoplayer", {item.Path, "share", newValue})
end

local function HandlePosition(setTime)
    if not CONFIG["NetworkSync"] then
        VideoPlayer.SetPosition(setTime)
        return
    end
    Network.SendToServer("hypernex.videoplayer", {item.Path, "position", setTime})
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
PlayFromURLButton.RegisterClick(SandboxFunc().SetAction(function()
    -- Do not allow change when working
    if isWorking then return end
    if CONFIG["NetworkSync"] and (SharingEnabled or LocalPlayer.IsHost) then
        -- There are network sync perms
        LoadAndPlayNewVideo(URLTextInput.GetText())
    elseif not CONFIG["NetworkSync"] then
        -- There is no NetworkSync
        LoadAndPlayNewVideo(URLTextInput.GetText())
    end
end))

PlayPauseButton.RegisterClick(SandboxFunc().SetAction(function()
    if isWorking then return end
    if not CanControl() then return end
    HandlePausePlay(not VideoPlayer.IsPlaying())
end))

LoopToggle.RegisterValueChanged(SandboxFunc().SetAction(function()
    if overrideToggleLoop then return end
    if not CanControl() then
        overrideToggleLoop = true
        LoopToggle.SetToggle(VideoPlayer.IsLooping())
        overrideToggleLoop = false
        return
    end
    HandleLoop(not VideoPlayer.IsLooping())
end))

ShareToggle.RegisterValueChanged(SandboxFunc().SetAction(function()
    if toggleFromNet then return end
    if not CanControl() then
        ShareToggle.SetToggle(SharingEnabled)
        return
    end
    HandleSharing(not SharingEnabled)
    ShareToggle.SetToggle(SharingEnabled)
end))

VolumeSlider.RegisterValueChanged(SandboxFunc().SetAction(function(value)
    VideoPlayer.SetVolume(value)
end))

JumpToButtonb.RegisterClick(SandboxFunc().SetAction(function()
    if isWorking or not CanControl() then return end
    HandlePosition(tonumber(JumpToTextInput.GetText()))
    JumpToTextInput.SetText("")
end))

-- Runtime Events
Runtime.OnUpdate(SandboxFunc().SetAction(function()
    if isWorking then return end
    if not VideoPlayer.IsPlaying() then return end
    local currentPosition = convertToHMS(VideoPlayer.GetPosition())
    local endPosition = convertToHMS(VideoPlayer.GetLength())
    PositionTextLabel.SetText(tostring(currentPosition).." - "..tostring(endPosition))
    PositionSliders.SetRange(0, VideoPlayer.GetLength())
    PositionSliders.SetValue(VideoPlayer.GetPosition())
end))

Runtime.RepeatSeconds(SandboxFunc().SetAction(function()
    if not CONFIG["NetworkSync"] then return end
    if not LocalPlayer.IsHost then return end
    if not VideoPlayer.IsPlaying() then return end
    if isFirstNetLoad then return end
    Network.SendToServer("hypernex.videoplayer", {item.Path, "position_", VideoPlayer.GetPosition()})
end), 3)

-- Network Handling
if not CONFIG["NetworkSync"] then
    if not CONFIG["StartingURL"] == "" then LoadAndPlayNewVideo(CONFIG["StartingURL"]) end
    return
end

Events.Subscribe(ScriptEvent.OnServerNetworkEvent, SandboxFunc().SetAction(function(eventName, eventArgs) 
    -- Do not handle if it is not for us
    if not eventName == "hypernex.videoplayer" then return end
    -- How a message looks
    -- eventArgs[1] - Path
    -- eventArgs[2] - Key
    -- eventArgs[3] - Value
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
        VideoPlayer.Pause()
        PlayPauseTextLabel.SetText("Resume")
    end
    if eventArgs[2] == "play" then
        if isWorking then return end
        VideoPlayer.Play()
        PlayPauseTextLabel.SetText("Pause")
    end
    if eventArgs[2] == "time" then
        if isWorking then return end
        VideoPlayer.SetPosition(eventArgs[3])
    end
    if eventArgs[2] == "share" then
        SharingEnabled = eventArgs[3]
        toggleFromNet = true
        ShareToggle.SetToggle(SharingEnabled)
        toggleFromNet = false
    end
    if eventArgs[2] == "loop" then VideoPlayer.SetLoop(eventArgs[3]) end
    if eventArgs[2] == "position" then
        if isWorking then return end
        VideoPlayer.SetPosition(tonumber(eventArgs[3]))
    end
    if eventArgs[2] == "get" then
        SharingEnabled = eventArgs[3]
        VideoPlayer.SetLoop(eventArgs[5])
        isFirstNetLoad = tonumber(eventArgs[6]) > 0
        if eventArgs[4] ~= "" then
            shouldPlayOnSync = not eventArgs[7]
            HandleNewVideo(eventArgs[4])
            if eventArgs[7] then
                PlayPauseTextLabel.SetText("Resume")
            else
                PlayPauseTextLabel.SetText("Pause")
            end
        elseif not CONFIG["StartingURL"] == "" and LocalPlayer.IsHost then
            LoadAndPlayNewVideo(CONFIG["StartingURL"])
        end
    end
    if eventArgs[2] == "getposition" then
        -- TODO: Better Desync prevention
        if isFirstNetLoad and LocalPlayer.IsHost then Network.SendToServer("hypernex.videoplayer", {item.Path, "position", eventArgs[3]}) end
        -- We now know that there has been some form of initiation with a net load
        isFirstNetLoad = false
        -- We are already loading, cache and wait
        if isWorking then
            gotSync = true
            syncPosition = eventArgs[3]
            return
        end
        gotSync = false
        VideoPlayer.SetPosition(tonumber(eventArgs[3]))
    end
end))

Runtime.RunAfterSeconds(SandboxFunc().SetAction(function()
    Network.SendToServer("hypernex.videoplayer", {item.Path, "get"})
end), 5)