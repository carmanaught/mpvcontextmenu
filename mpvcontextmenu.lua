--[[ *************************************************************
 * Context menu for mpv using Tcl/Tk.
 * Originally by Avi Halachmi (:avih) https://github.com/avih
 * Extended by Thomas Carmichael (carmanught) https://github.com/carmanaught
 * 
 * Features:
 * - Comprehensive sub-menus providing access to various mpv functionality
 * - Dynamic menu items and commands, disabled items, separators.
 * - Reasonably well behaved/integrated considering it's an external application.
 * - Configurable options for some values (changes visually in menu too)
 * 
 * TODO:
 * - Possibly look at reading keybindings from input.conf
 *
 * Setup:
 * - Make sure Tcl/Tk is installed and `wish` is accessible and works.
 *   - Alternatively, configure `interpreter` below to `tclsh`, which may work smoother.
 *   - For windows, download a zip from http://www.tcl3d.org/html/appTclkits.html
 *     extract and then rename to wish.exe and put it at the path or at the mpv.exe dir.
 *     - Or, tclsh/wish from git/msys2(mingw) works too - set `interpreter` below.
 * - Put mpvcontextmenu.lua (this file) and mpvcontextmenu.tcl along with langcodes.lua
 *   and zenity-dialogs.lua in the mpv scripts dir.
 * - Add a key/mouse binding at input.conf, e.g. "MOUSE_BTN2 script_message mpv_context_menu"
 * - Once it works, configure the context_menu items below to your liking.
 *
 * 2017-02-02 - Version 0.1 - Initial version (avih)
 * 2017-07-19 - Version 0.2 - Extensive rewrite (carmanught)
 * 2017-07-20 - Version 0.3 - Add/remove/update menus and include zenity bindings (carmanught)
 * 2017-07-22 - Version 0.4 - Reordered context_menu items, changed table length check, modify
 *                            menu build iterator slightly and add options (carmanaught)
 * 2017-07-27 - Version 0.5 - Added function (with recursion) to build menus (allows dynamic
 *                            menus of up to 6 levels (top level + 5 sub-menu levels)) and
 *                            add basic menu that will work when nothing is playing.
 * 
 ***************************************************************
--]]

local langcodes = require "langcodes"
local utils = require 'mp.utils'
local verbose = false  -- true -> Dump console messages also without -v
function info(x) mp.msg[verbose and "info" or "verbose"](x) end
function mpdebug(x) mp.msg.info(x) end -- For printing other debug without verbose
function noop() end
local propNative = mp.get_property_native

-- Set options
require 'mp.options'
local opt = {
    -- Play > Speed - Percentage
    playSpeed = 5,
    -- Play > Seek - Seconds
    seekSmall = 5,
    seekMedium = 30,
    seekLarge = 60,
    -- Video > Aspect - Percentage
    vidAspect = 0.1,
    -- Video > Zoom - Percentage
    vidZoom = 0.1,
    -- Video > Screen Position - Percentage
    vidPos = 0.1,
    -- Video > Color - Percentage
    vidColor = 1,
    -- Audio > Sync - Milliseconds
    audSync = 100,
    -- Audio > Volume - Percentage
    audVol = 2,
    -- Subtitle > Position - Percentage
    subPos = 1,
    -- Subtitle > Scale - Percentage
    subScale = 1,
    -- Subtitle > Sync
    subSync = 100, -- Milliseconds
}
read_options(opt)

-- Set some constant values
local SEP = "separator"
local CASCADE = "cascade"
local COMMAND = "command"
local CHECK = "checkbutton"
local RADIO = "radiobutton"
local AB = "ab-button"

function round(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

-- Edition menu functions
local function enableEdition()
    local editionState = false
    if (propNative("edition-list/count") < 1) then editionState = true end
    return editionState
end

local function checkEdition(editionNum)
    local editionEnable, editionCur = false, propNative("edition")
    if (editionNum == editionCur) then editionEnable = true end
    return editionEnable
end

local function editionMenu()
    local editionCount = propNative("edition-list/count")
    local editionMenuVal = {}
    
    if not (editionCount == 0) then
        for editionNum=0, (editionCount - 1), 1 do
            local editionTitle = propNative("edition-list/" .. editionNum .. "/title")
            if not (editionTitle) then editionTitle = "Edition " .. (editionNum + 1) end
            
            local editionCommand = "set edition " .. editionNum
            table.insert(editionMenuVal, {RADIO, editionTitle, "", editionCommand, function() return checkEdition(editionNum) end, false})
        end
    else
        table.insert(editionMenuVal, {COMMAND, "No Editions", "", "", "", true})
    end
    
    return editionMenuVal
end

-- Chapter menu functions
local function enableChapter()
    local chapterEnable = false
    if (propNative("chapter-list/count") < 1) then chapterEnable = true end
    return chapterEnable
end

local function checkChapter(chapterNum)
    local chapterState, chapterCur = false, propNative("chapter")
    if (chapterNum == chapterCur) then chapterState = true end
    return chapterState
end

local function chapterMenu()
    local chapterCount = propNative("chapter-list/count")
    local chapterMenuVal = {}
    
    chapterMenuVal = {
        {COMMAND, "Previous", "PgUp", "no-osd add chapter -1", "", false},
        {COMMAND, "Next", "PgDown", "no-osd add chapter 1", "", false},
    }
    if not (chapterCount == 0) then
        for chapterNum=0, (chapterCount - 1), 1 do
            local chapterTitle = propNative("chapter-list/" .. chapterNum .. "/title")
            if not (chapterTitle) then chapterTitle = "Chapter " .. (chapterNum + 1) end
            
            local chapterCommand = "set chapter " .. chapterNum
            if (chapterNum == 0) then table.insert(chapterMenuVal, {SEP}) end
            table.insert(chapterMenuVal, {RADIO, chapterTitle, "", chapterCommand, function() return checkChapter(chapterNum) end, false})
        end
    end
    
    return chapterMenuVal
end

-- Track type count function to iterate through the track-list and get the number of
-- tracks of the type specified. Types are:  video / audio / sub. This actually
-- returns an array of track numbers of the given type so that the track-list/N/
-- properties can be obtained.

local function trackCount(checkType)
    local tracksCount = propNative("track-list/count")
    local trackCountVal = {}
    
    if not (tracksCount < 1) then 
        for i = 0, (tracksCount - 1), 1 do
            local trackType = propNative("track-list/" .. i .. "/type")
            if (trackType == checkType) then table.insert(trackCountVal, i) end
        end
    end
    
    return trackCountVal
end

-- Track check function, to check if a track is selected. This isn't specific to a set
-- track type and can be used for the video/audio/sub tracks, since they're all part
-- of the track-list.

local function checkTrack(trackNum)
    local trackState, trackCur = false, propNative("track-list/" .. trackNum .. "/selected")
    if (trackCur == true) then trackState = true end
    return trackState
end

-- Video > Track menu functions
local function enableVidTrack()
    local vidTrackEnable, vidTracks = false, trackCount("video")
    if (#vidTracks < 1) then vidTrackEnable = true end
    return vidTrackEnable
end

local function vidTrackMenu()
    local vidTrackMenuVal, vidTrackCount = {}, trackCount("video")
     
    if not (#vidTrackCount == 0) then
        for i = 1, #vidTrackCount, 1 do
            local vidTrackNum = vidTrackCount[i]
            local vidTrackID = propNative("track-list/" .. vidTrackNum .. "/id")
            local vidTrackTitle = propNative("track-list/" .. vidTrackNum .. "/title")
            if not (vidTrackTitle) then vidTrackTitle = "Video Track " .. i end
            
            local vidTrackCommand = "set vid " .. vidTrackID
            table.insert(vidTrackMenuVal, {RADIO, vidTrackTitle, "", vidTrackCommand, function() return checkTrack(vidTrackNum) end, false})
        end
    else
        table.insert(vidTrackMenuVal, {RADIO, "No Video Tracks", "", "", "", true})
    end
    
    return vidTrackMenuVal
end

-- Convert ISO 639-1/639-2 codes to be full length language names. The full length names 
-- are obtained by using the property accessor with the iso639_1/_2 tables stored in
-- the langcodes.lua file (require "langcodes" above).
function getLang(trackLang)
    trackLang = string.upper(trackLang)
    if (string.len(trackLang) == 2) then trackLang = iso639_1[trackLang]
    elseif (string.len(trackLang) == 3) then trackLang = iso639_2[trackLang] end
    return trackLang
end

-- Audio > Track menu functions
local function audTrackMenu()
    local audTrackMenuVal, audTrackCount = {}, trackCount("audio")
    
    audTrackMenuVal = {
         {COMMAND, "Open File", "", "script-binding add_audio_zenity", "", false},
         {COMMAND, "Reload File", "", "audio-reload", "", false},
         {COMMAND, "Remove", "", "audio-remove", "", false},
         {SEP},
         {COMMAND, "Select Next", "Ctrl+A", "cycle audio", "", false},
    }
    if not (#audTrackCount == 0) then
        for i = 1, (#audTrackCount), 1 do
            local audTrackNum = audTrackCount[i]
            local audTrackID = propNative("track-list/" .. audTrackNum .. "/id")
            local audTrackTitle = propNative("track-list/" .. audTrackNum .. "/title")
            local audTrackLang = propNative("track-list/" .. audTrackNum .. "/lang")
            -- Convert ISO 639-1/2 codes
            if not (audTrackLang == nil) then audTrackLang = getLang(audTrackLang) and getLang(audTrackLang) or audTrackLang end
            
            if (audTrackTitle) then audTrackTitle = audTrackTitle .. ((audTrackLang ~= nil) and " (" .. audTrackLang .. ")" or "")
            elseif (audTrackLang) then audTrackTitle = audTrackLang
            else audTrackTitle = "Audio Track " .. i end
            
            local audTrackCommand = "set aid " .. audTrackID
            if (i == 1) then
                table.insert(audTrackMenuVal, {COMMAND, "Select None", "", "set aid 0", "", false})
                table.insert(audTrackMenuVal, {SEP})
            end
            table.insert(audTrackMenuVal, {RADIO, audTrackTitle, "", audTrackCommand, function() return checkTrack(audTrackNum) end, false})
        end
    end
    
    return audTrackMenuVal
end

-- Subtitle label
local function subVisLabel() return propNative("sub-visibility") and "Hide" or "Un-hide" end

-- Subtitle > Track menu functions

local function subTrackMenu()
    local subTrackMenuVal, subTrackCount = {}, trackCount("sub")
    
    subTrackMenuVal = {
        {COMMAND, "Open File", "(Shift+F)", "script-binding add_subtitle_zenity", "", false},
        {COMMAND, "Reload File", "", "sub-reload", "", false},
        {COMMAND, "Clear File", "", "sub-remove", "", false},
        {SEP},
        {COMMAND, "Select Next", "Shift+N", "cycle sub", "", false},
        {COMMAND, "Select Previous", "Ctrl+Shift+N", "cycle sub down", "", false},
        {CHECK, function() return subVisLabel() end, "V", "cycle sub-visibility", function() return not propNative("sub-visibility") end, false},
    }
    if not (#subTrackCount == 0) then
        for i = 1, (#subTrackCount), 1 do
            local subTrackNum = subTrackCount[i]
            local subTrackID = propNative("track-list/" .. subTrackNum .. "/id")
            local subTrackTitle = propNative("track-list/" .. subTrackNum .. "/title")
            local subTrackLang = propNative("track-list/" .. subTrackNum .. "/lang")
            -- Convert ISO 639-1/2 codes
            if not (subTrackLang == nil) then subTrackLang = getLang(subTrackLang) and getLang(subTrackLang) or subTrackLang end
            
            if (subTrackTitle) then subTrackTitle = subTrackTitle .. ((subTrackLang ~= nil) and " (" .. subTrackLang .. ")" or "")
            elseif (subTrackLang) then subTrackTitle = subTrackLang
            else subTrackTitle = "Subtitle Track " .. i end
            
            local subTrackCommand = "set sid " .. subTrackID
            if (i == 1) then
                table.insert(subTrackMenuVal, {COMMAND, "Select None", "", "set sid 0", "", false})
                table.insert(subTrackMenuVal, {SEP})
            end
            table.insert(subTrackMenuVal, {RADIO, subTrackTitle, "", subTrackCommand, function() return checkTrack(subTrackNum) end, false})
        end
    end
    
    return subTrackMenuVal
end

local function stateABLoop()
    local abLoopState = ""
    local abLoopA, abLoopB = propNative("ab-loop-a"), propNative("ab-loop-b")
    
    if (abLoopA == "no") and (abLoopB == "no") then abLoopState =  "off"
    elseif not (abLoopA == "no") and (abLoopB == "no") then abLoopState = "a"
    elseif not (abLoopA == "no") and not (abLoopB == "no") then abLoopState = "b" end
    
    return abLoopState
end

-- Aspect Ratio radio item check
local function stateRatio(ratioVal)
    -- Ratios and Decimal equivalents
    -- Ratios:    "4:3" "16:10"  "16:9" "1.85:1" "2.35:1"
    -- Decimal: "1.333" "1.600" "1.778"  "1.850"  "2.350"
    local ratioState = false
    local ratioCur = round(propNative("video-aspect"), 3)
    
    if (ratioVal == "4:3") and (ratioCur == round(4/3, 3)) then ratioState = true
    elseif (ratioVal == "16:10") and (ratioVal == round(16/10, 3)) then ratioState = true
    elseif (ratioVal == "16:9") and (ratioVal == round(16/9, 3)) then ratioState = true
    elseif (ratioVal == "1.85:1") and (ratioVal == round(1.85/1, 3)) then ratioState = true
    elseif (ratioVal == "2.35:1") and (ratioVal == round(2.35/1, 3)) then ratioState = true
    end
    
    return ratioState
end

-- Video Rotate radio item check
local function stateRotate(rotateVal)
    local rotateState, rotateCur = false, propNative("video-rotate")
    if (rotateVal == rotateCur) then rotateState = true end
    return rotateState
end

-- Video Alignment radio item checks
local function stateAlign(alignAxis, alignPos)
    local alignState = false
    local alignValY, alignValX = propNative("video-align-y"), propNative("video-align-x")
    
    -- This seems a bit unwieldy. Should look at simplifying if possible.
    if (alignAxis == "y") then
        if (alignPos == alignValY) then alignState = true end
    elseif (alignAxis == "x") then
        if (alignPos == alignValX) then alignState = true end
    end
        
    return alignState
end

-- Deinterlacing radio item check
local function stateDeInt(deIntVal)
    local deIntState, deIntCur = false, propNative("deinterlace")
    if (deIntVal == deIntCur) then deIntState = true end
    return deIntState
end

local function stateFlip(flipVal)
    local vfState, vfVals = false, propNative("vf")
    for i, vf in pairs(vfVals) do
        if (vf["name"] == flipVal) then vfState = true end
    end
    return vfState
end

-- Mute label
local function muteLabel() return propNative("mute") and "Un-mute" or "Mute" end

local function stateAudChannel(audVal)
    local audState, audLayout = false, propNative("audio-channels")
    -- Audio channel layout radio item check
    -- Based on "mpv --audio-channels=help", reordered/renamed in part as per Bomi, intended
    -- to be accessed via (audio_channels(layout) = propNative(audio-channels)) and true or false
    local audio_channels = { ["auto"] = "auto", ["auto-safe"] = "auto-safe",  ["empty"] = "empty", ["mono"] = "mono", ["stereo"] = "stereo", ["2.1"] = "2.1", ["3.0"] = "3.0", ["3.0(back)"] = "3.0(back)", ["3.1"] = "3.1", ["3.1(back)"] = "3.1(back)", ["quad"] = "quad", ["quad(side)"] = "quad(side)", ["4.0"] = "4.0", ["4.1(alsa)"] = "4.1(alsa)", ["4.1"] = "4.1", ["5.0(alsa)"] = "5.0(alsa)", ["5.0"] = "5.0", ["5.0(side)"] = "5.0(side)", ["5.1(alsa)"] = "5.1(alsa)", ["5.1"] = "5.1", ["5.1(side)"] = "5.1(side)", ["6.0"] = "6.0", ["6.0(front)"] = "6.0(front)", ["hexagonal"] = "hexagonal", ["6.1"] = "6.1", ["6.1(top)"] = "6.1(top)", ["6.1(back)"] = "6.1(back)", ["6.1(front)"] = "6.1(front)", ["7.0(front)"] = "7.0(front)", ["7.0(rear)"] = "7.0(rear)", ["7.0(front)"] = "7.0(front)", ["7.1(alsa)"] = "7.1(alsa)", ["7.1"] = "7.1", ["7.1(wide)"] = "7.1(wide)", ["7.1(wide-side)"] = "7.1(wide-side)", ["7.1(rear)"] = "7.1(rear)", ["octagonal"] = "octagonal" }
    
    audState = (audio_channels[audVal] == audLayout) and true or false
    return audState
end

-- Subtitle Alignment radio item check
local function stateSubAlign(subAlignVal)
    local subAlignState, subAlignCur = false, propNative("sub-align-y")
    subAlignState = (subAlignVal == subAlignCur) and true or false
    return subAlignState
end

-- Subtitle Position radio item check
local function stateSubPos(subPosVal)
    local subPosState, subPosCur = false, propNative("image-subs-video-resolution")
    subPosState = (subPosVal == subPosCur) and true or false
    return subPosState
end

local function movePlaylist(direction)
    local playlistPos, newPos = propNative("playlist-pos"), 0
    -- We'll remove 1 here to "0 index" the value since we're using it with playlist-pos
    local playlistCount = propNative("playlist-count") - 1
    
    if (direction == "up") then
        newPos = playlistPos - 1
        if not (playlistPos == 0) then
            mp.commandv("plalist-move", playlistPos, newPos)
        else mp.osd_message("Can't move item up any further") end
    elseif (direction == "down") then
        if not (playlistPos == playlistCount) then
            newPos = playlistPos + 2
            mp.commandv("plalist-move", playlistPos, newPos)
        else mp.osd_message("Can't move item up any further") end
    end
end

local function stateLoop()
    local loopState, loopVal = false, propNative("loop-playlist")
    if not (tostring(loopVal) == "false") then loopState = true end
    return loopState
end

local function stateOnTop(onTopVal)
    local onTopState, onTopCur = false, propNative("ontop")
    onTopState = (onTopVal == onTopCur) and true or false
    return onTopState
end

--[[ ************ CONFIG: start ************ ]]--

local context_menu = {}

-- Format for object arrays
-- {Item Type, Label, Accelerator, Command, Item State, Item Disable}

-- Item Type - The type of item, e.g. CASCADE, COMMAND, CHECK, RADIO, etc
-- Label - The label for the item
-- Accelerator - The text shortcut/accelerator for the item
-- Command - This is the command to run when the item is clicked
-- Item State - The state of the item (selected/unselected). A/B Repeat is a special case.
-- Item Disable - Whether to disable

-- Item Type, Label and Accelerator should all evaluate to strings as a result of the return
-- from a function or be strings themselves.
-- Command can be a function or string, this will be handled after a click.
-- Item State and Item Disable should normally be boolean but can be a string for A/B Repeat

-- This is to be shown when nothing is open yet and is a small subset of the greater menu that
-- will be overwritten when the full menu is created.
context_menu = {
    {CASCADE, "Open", "open_menu", "", "", false},
    {SEP},
    {CASCADE, "Window", "window_menu", "", "", false},
    {SEP},
    {COMMAND, "Dismiss Menu", "", noop, "", false},
    {COMMAND, "Quit", "", "quit", "", false},
    
    open_menu = {
        {COMMAND, "File", "Ctrl+F", "script-binding add_files_zenity", "", false},
        {COMMAND, "Folder", "Ctrl+G", "script-binding add_folder_zenity", "", false},
        {COMMAND, "URL", "", "script-binding open_url_zenity", "", false},
    },
    
    window_menu = {
        {CASCADE, "Stays on Top", "staysontop_menu", "", "", false},
        {CHECK, "Remove Frame", "", "cycle border", function() return not propNative("border") end, false},
        {SEP},
        {COMMAND, "Toggle Fullscreen", "F", "cycle fullscreen", "", false},
        {COMMAND, "Enter Fullscreen", "", "set fullscreen \"yes\"", "", false},
        {COMMAND, "Exit Fullscreen", "Escape", "set fullscreen \"no\"", "", false},
        {SEP},
        {COMMAND, "Close", "Ctrl+W", "quit", "", false},
    },
    
    staysontop_menu = {
        {COMMAND, "Select Next", "", "cycle ontop", "", false},
        {SEP},
        {RADIO, "Off", "", "set ontop \"yes\"", function() return stateOnTop(false) end, false},
        {RADIO, "On", "", "set ontop \"no\"", function() return stateOnTop(true) end, false},
    }, 
}

-- DO NOT create the "playing" menu tables until AFTER the file has loaded as we're unable to
-- dynamically create some menus if it tries to build the table before the file is loaded.
-- A prime example is the chapter-list or track-list values, which are unavailable until
-- the file has been loaded.

mp.register_event("file-loaded", function()
    context_menu = {
        {CASCADE, "Open", "open_menu", "", "", false},
        {SEP},
        {CASCADE, "Play", "play_menu", "", "", false},
        {CASCADE, "Video", "video_menu", "", "", false},
        {CASCADE, "Audio", "audio_menu", "", "", false},
        {CASCADE, "Subtitle", "subtitle_menu", "", "", false},
        {SEP},
        {CASCADE, "Tools", "tools_menu", "", "", false},
        {CASCADE, "Window", "window_menu", "", "", false},
        {SEP},
        {COMMAND, "Dismiss Menu", "", noop, "", false},
        {COMMAND, "Quit", "", "quit", "", false},
        
        open_menu = {
            {COMMAND, "File", "Ctrl+F", "script-binding add_files_zenity", "", false},
            {COMMAND, "Folder", "Ctrl+G", "script-binding add_folder_zenity", "", false},
            {COMMAND, "URL", "", "script-binding open_url_zenity", "", false},
        },
        
        play_menu = {
            {COMMAND, "Play/Pause", "Space", "cycle pause", "", false},
            {COMMAND, "Stop", "Ctrl+Space", "stop", "", false},
            {SEP},
            {COMMAND, "Previous", "<", "playlist-prev", "", false},
            {COMMAND, "Next", ">", "playlist-next", "", false},
            {SEP},
            {CASCADE, "Speed", "speed_menu", "", "", false},
            {CASCADE, "A-B Repeat", "abrepeat_menu", "", "", false},
            {SEP},
            {CASCADE, "Seek", "seek_menu", "", "", false},
            {CASCADE, "Title/Edition", "edition_menu", "", "", function() return enableEdition() end},
            {CASCADE, "Chapter", "chapter_menu", "", "", function() return enableChapter() end},
        },
        
        speed_menu = {
            {COMMAND, "Reset", "Backspace", "no-osd set speed 1.0 ; show-text \"Play Speed - Reset\"", "", false},
            {SEP},
            {COMMAND, "+" .. opt.playSpeed .. "%", "=", "multiply speed " .. (1 + (opt.playSpeed / 100)), "", false},
            {COMMAND, "-" .. opt.playSpeed .. "%", "-", "multiply speed " .. (1 - (opt.playSpeed / 100)), "", false},
        },
        
        abrepeat_menu = {
            {AB, "Set/Clear A-B Loop", "R", "ab-loop", function() return stateABLoop() end, false},
            {CHECK, "Toggle Infinite Loop", "", "cycle-values loop-file \"inf\" \"no\"", propNative("loop-file"), false},
        },
        
        seek_menu = {
            {COMMAND, "Beginning", "Ctrl+Home", "no-osd seek 0 absolute", "", false},
            {SEP},
            {COMMAND, "+" .. opt.seekSmall .. " Sec", "Right", "no-osd seek " .. opt.seekSmall, "", false},
            {COMMAND, "-" .. opt.seekSmall .. " Sec", "Left", "no-osd seek -" .. opt.seekSmall, "", false},
            {COMMAND, "+" .. opt.seekMedium .. " Sec", "Up", "no-osd seek " .. opt.seekMedium, "", false},
            {COMMAND, "-" .. opt.seekMedium .. " Sec", "Down", "no-osd seek -" .. opt.seekMedium, "", false},
            {COMMAND, "+" .. opt.seekLarge .. " Sec", "End", "no-osd seek " .. opt.seekLarge, "", false},
            {COMMAND, "-" .. opt.seekLarge .. " Sec", "Home", "no-osd seek -" .. opt.seekLarge, "", false},
            {SEP},
            {COMMAND, "Previous Frame", "Alt+Left", "frame-back-step", "", false},
            {COMMAND, "Next Frame", "Alt+Right", "frame-step", "", false},
            {COMMAND, "Next Black Frame", "Alt+b", "script-binding skip_scene", "", false},
            {SEP},
            {COMMAND, "Previous Subtitle", "", "no-osd sub-seek -1", "", false},
            {COMMAND, "Current Subtitle", "", "no-osd sub-seek 0", "", false},
            {COMMAND, "Next Subtitle", "", "no-osd sub-seek 1", "", false},
        },
        
        -- Use functions returning arrays/tables, since we don't need these menus if there
        -- aren't any editions or any chapters to seek through.
        edition_menu = editionMenu(),
        chapter_menu = chapterMenu(),
        
        video_menu = {
            {CASCADE, "Track", "vidtrack_menu", "", "", function() return enableVidTrack() end},
            {SEP},
            {CASCADE, "Take Screenshot", "screenshot_menu", "", "", false},
            {SEP},
            {CASCADE, "Aspect Ratio", "aspect_menu", "", "", false},
            {CASCADE, "Zoom", "zoom_menu", "", "", false},
            {CASCADE, "Rotate", "rotate_menu", "", "", false},
            {CASCADE, "Screen Position", "screenpos_menu", "", "", false},
            {CASCADE, "Screen Alignment", "screenalign_menu", "", "", false},
            {SEP},
            {CASCADE, "Deinterlacing", "deint_menu", "", "", false},
            {CASCADE, "Filter", "filter_menu", "", "", false},
            {CASCADE, "Adjust Color", "color_menu", "", "", false},
        },
        
        -- Use function to return list of Video Tracks
        vidtrack_menu = vidTrackMenu(),
        
        screenshot_menu = {
            {COMMAND, "Screenshot", "Ctrl+S", "async screenshot", "", false},
            {COMMAND, "Screenshot (No Subs)", "Alt+S", "async screenshot video", "", false},
            {COMMAND, "Screenshot (Subs/OSD/Scaled)", "", "async screenshot window", "", false},
        },
        
        aspect_menu = {
            {COMMAND, "Reset", "Ctrl+Shift+R", "no-osd set video-aspect \"-1\" ; no-osd set video-aspect \"-1\" ; show-text \"Video Aspect Ratio - Reset\"", "", false},
            {COMMAND, "Select Next", "", "cycle-values video-aspect \"4:3\" \"16:10\" \"16:9\" \"1.85:1\" \"2.35:1\" \"-1\" \"-1\"", "", false},
            {SEP},
            {RADIO, "4:3 (TV)", "", "set video-aspect \"4:3\"", function() return stateRatio("4:3") end, false},
            {RADIO, "16:10 (Wide Monitor)", "", "set video-aspect \"16:10\"", function() return stateRatio("16:10") end, false},
            {RADIO, "16:9 (HDTV)", "", "set video-aspect \"16:9\"", function() return stateRatio("16:9") end, false},
            {RADIO, "1.85:1 (Wide Vision)", "", "set video-aspect \"1.85:1\"", function() return stateRatio("1.85:1") end, false},
            {RADIO, "2.35:1 (CinemaScope)", "", "set video-aspect \"2.35:1\"", function() return stateRatio("2.35:1") end, false},
            {SEP},
            {COMMAND, "+" .. opt.vidAspect .. "%", "Ctrl+Shift+A", "add video-aspect " .. (opt.vidAspect / 100), "", false},
            {COMMAND, "-" .. opt.vidAspect .. "%", "Ctrl+Shift+D", "add video-aspect -" .. (opt.vidAspect / 100), "", false},
        },
        
        zoom_menu = {
            {COMMAND, "Reset", "Shift+R", "no-osd set panscan 0 ; show-text \"Pan/Scan - Reset\"", "", false},
            {SEP},
            {COMMAND, "+" .. opt.vidZoom .. "%", "Shift+T", "add panscan " .. (opt.vidZoom / 100), "", false},
            {COMMAND, "-" .. opt.vidZoom .. "%", "Shift+G", "add panscan -" .. (opt.vidZoom / 100), "", false},
        },
        
        rotate_menu = {
            {COMMAND, "Reset", "", "set video-rotate \"0\"", "", false},
            {COMMAND, "Select Next", "", "cycle-values video-rotate \"0\" \"90\" \"180\" \"270\"", "", false},
            {SEP},
            {RADIO, "0°", "", "set video-rotate \"0\"", function() return stateRotate(0) end, false},
            {RADIO, "90°", "", "set video-rotate \"90\"", function() return stateRotate(90) end, false},
            {RADIO, "180°", "", "set video-rotate \"180\"", function() return stateRotate(180) end, false},
            {RADIO, "270°", "", "set video-rotate \"270\"", function() return stateRotate(270) end, false},
        },
        
        screenpos_menu = {
            {COMMAND, "Reset", "Shift+X", "no-osd set video-pan-x 0 ; no-osd set video-pan-y 0 ; show-text \"Video Pan - Reset\"", "", false},
            {SEP},
            {COMMAND, "Horizontally +" .. opt.vidPos .. "%", "Shift+D", "add video-pan-x " .. (opt.vidPos / 100), "", false},
            {COMMAND, "Horizontally -" .. opt.vidPos .. "%", "Shift+A", "add video-pan-x -" .. (opt.vidPos / 100), "", false},
            {SEP},
            {COMMAND, "Vertically +" .. opt.vidPos .. "%", "Shift+S", "add video-pan-y -" .. (opt.vidPos / 100), "", false},
            {COMMAND, "Vertically -" .. opt.vidPos .. "%", "Shift+W", "add video-pan-y " .. (opt.vidPos / 100), "", false},
        },
        
        screenalign_menu = {
            -- Y Values: -1 = Top, 0 = Vertical Center, 1 = Bottom
            -- X Values: -1 = Left, 0 = Horizontal Center, 1 = Right
            {RADIO, "Top", "", "no-osd set video-align-y -1", function() return stateAlign("y",-1) end, false},
            {RADIO, "Vertical Center", "", "no-osd set video-align-y 0", function() return stateAlign("y",0) end, false},
            {RADIO, "Bottom", "", "no-osd set video-align-y 1", function() return stateAlign("y",1) end, false},
            {SEP},
            {RADIO, "Left", "", "no-osd set video-align-x -1", function() return stateAlign("x",-1) end, false},
            {RADIO, "Horizontal Center", "", "no-osd set video-align-x 0", function() return stateAlign("x",0) end, false},
            {RADIO, "Right", "", "no-osd set video-align-x 1", function() return stateAlign("x",1) end, false},
        },
        
        deint_menu = {
            {COMMAND, "Toggle", "Ctrl+D", "cycle deinterlace", "", false},
            {COMMAND, "Auto", "", "set deinterlace \"auto\"", "", false},
            {SEP},
            {RADIO, "Off", "", "no-osd set deinterlace \"no\"", function() return stateDeInt(false) end, false},
            {RADIO, "On", "", "no-osd set deinterlace \"yes\"", function() return stateDeInt(true) end, false},
        },
        
        filter_menu = {
            {CHECK, "Flip Vertically", "", "no-osd vf toggle vflip", function() return stateFlip("vflip") end, false},
            {CHECK, "Flip Horizontally", "", "no-osd vf toggle hflip", function() return stateFlip("hflip") end, false}
        },
        
        color_menu = {
            {COMMAND, "Reset", "O", "no-osd set brightness 0 ; no-osd set contrast 0 ; no-osd set hue 0 ; no-osd set saturation 0 ; show-text \"Colors - Reset\"", "", false},
            {SEP},
            {COMMAND, "Brightness +" .. opt.vidColor .. "%", "T", "add brightness " .. opt.vidColor, "", false},
            {COMMAND, "Brightness -" .. opt.vidColor .. "%", "G", "add brightness -" .. opt.vidColor, "", false},
            {COMMAND, "Contrast +" .. opt.vidColor .. "%", "Y", "add contrast " .. opt.vidColor, "", false},
            {COMMAND, "Contrast -" .. opt.vidColor .. "%", "H", "add contrast -" .. opt.vidColor, "", false},
            {COMMAND, "Saturation +" .. opt.vidColor .. "%", "U", "add saturation " .. opt.vidColor, "", false},
            {COMMAND, "Saturation -" .. opt.vidColor .. "%", "J", "add saturation -" .. opt.vidColor, "", false},
            {COMMAND, "Hue +" .. opt.vidColor .. "%", "I", "add hue " .. opt.vidColor, "", false},
            {COMMAND, "Hue -" .. opt.vidColor .. "%", "K", "add hue -" .. opt.vidColor, "", false},
        },
        
        audio_menu = {
            {CASCADE, "Track", "audtrack_menu", "", "", false},
            {CASCADE, "Sync", "audsync_menu", "", "", false},
            {SEP},
            {CASCADE, "Volume", "volume_menu", "", "", false},
            {CASCADE, "Channel Layout", "channel_layout", "", "", false},
        },
        
        -- Use function to return list of Audio Tracks        
        audtrack_menu = audTrackMenu(),
        
        audsync_menu = {
            {COMMAND, "Reset", "\\", "no-osd set audio-delay 0 ; show-text \"Audio Sync - Reset\"", "", false},
            {SEP},
            {COMMAND, "+" .. opt.audSync .. " ms", "]", "add audio-delay " .. (opt.audSync / 1000) .. "", "", false},
            {COMMAND, "-" .. opt.audSync .. " ms", "[", "add audio-delay -" .. (opt.audSync / 1000) .. "", "", false},
        },
        
        volume_menu = {
            {CHECK, function() return muteLabel() end, "", "cycle mute", function() return propNative("mute") end, false},
            {SEP},
            {COMMAND, "+" .. opt.audVol.. "%", "Shift+Up", "add volume " .. opt.audVol, "", false},
            {COMMAND, "-" .. opt.audVol.. "%", "Shift+Down", "add volume -" .. opt.audVol, "", false},
        },
        
        channel_layout = {
            {RADIO, "Auto", "", "set audio-channels \"\"", function() return stateAudChannel("auto") end, false},
            {RADIO, "Auto (Safe)", "", "set audio-channels \"\"", function() return stateAudChannel("auto-safe") end, false},
            {SEP},
            {RADIO, "Empty", "", "set audio-channels \"empty\"", function() return stateAudChannel("empty") end, false},
            {RADIO, "Mono", "", "set audio-channels \"mono\"", function() return stateAudChannel("mono") end, false},
            {RADIO, "Stereo", "", "set audio-channels \"stereo\"", function() return stateAudChannel("stereo") end, false},
            {RADIO, "2.1ch", "", "set audio-channels \"2.1\"", function() return stateAudChannel("2.1") end, false},
            {RADIO, "3.0ch", "", "set audio-channels \"3.0\"", function() return stateAudChannel("3.0") end, false},
            {RADIO, "3.0ch (Back)", "", "set audio-channels \"3.0(back)\"", function() return stateAudChannel("3.0(back)") end, false},
            {RADIO, "3.1ch", "", "set audio-channels \"3.1\"", function() return stateAudChannel("3.1") end, false},
            {RADIO, "3.1ch (Back)", "", "set audio-channels \"3.1(back)\"", function() return stateAudChannel("3.1(back)") end, false},
            {RADIO, "4.0ch", "", "set audio-channels \"quad\"", function() return stateAudChannel("quad") end, false},
            {RADIO, "4.0ch (Side)", "", "set audio-channels \"quad(side)\"", function() return stateAudChannel("quad(side)") end, false},
            {RADIO, "4.0ch (Diamond)", "", "set audio-channels \"4.0\"", function() return stateAudChannel("4.0") end, false},
            {RADIO, "4.1ch", "", "set audio-channels \"4.1(alsa)\"", function() return stateAudChannel("4.1(alsa)") end, false},
            {RADIO, "4.1ch (Diamond)", "", "set audio-channels \"4.1\"", function() return stateAudChannel("4.1") end, false},
            {RADIO, "5.0ch", "", "set audio-channels \"5.0(alsa)\"", function() return stateAudChannel("5.0(alsa)") end, false},
            {RADIO, "5.0ch (Alt.)", "", "set audio-channels \"5.0\"", function() return stateAudChannel("5.0") end, false},
            {RADIO, "5.0ch (Side)", "", "set audio-channels \"5.0(side)\"", function() return stateAudChannel("5.0(side)") end, false},
            {RADIO, "5.1ch", "", "set audio-channels \"5.1(alsa)\"", function() return stateAudChannel("5.1(alsa)") end, false},
            {RADIO, "5.1ch (Alt.)", "", "set audio-channels \"5.1\"", function() return stateAudChannel("5.1") end, false},
            {RADIO, "5.1ch (Side)", "", "set audio-channels \"5.1(side)\"", function() return stateAudChannel("5.1(side)") end, false},
            {RADIO, "6.0ch", "", "set audio-channels \"6.0\"", function() return stateAudChannel("6.0") end, false},
            {RADIO, "6.0ch (Front)", "", "set audio-channels \"6.0(front)\"", function() return stateAudChannel("6.0(front)") end, false},
            {RADIO, "6.0ch (Hexagonal)", "", "set audio-channels \"hexagonal\"", function() return stateAudChannel("hexagonal") end, false},
            {RADIO, "6.1ch", "", "set audio-channels \"6.1\"", function() return stateAudChannel("6.1") end, false},
            {RADIO, "6.1ch (Top)", "", "set audio-channels \"6.1(top)\"", function() return stateAudChannel("6.1(top)") end, false},
            {RADIO, "6.1ch (Back)", "", "set audio-channels \"6.1(back)\"", function() return stateAudChannel("6.1(back)") end, false},
            {RADIO, "6.1ch (Front)", "", "set audio-channels \"6.1(front)\"", function() return stateAudChannel("6.1(front)") end, false},
            {RADIO, "7.0ch", "", "set audio-channels \"7.0\"", function() return stateAudChannel("7.0") end, false},
            {RADIO, "7.0ch (Back)", "", "set audio-channels \"7.0(rear)\"", function() return stateAudChannel("7.0(rear)") end, false},
            {RADIO, "7.0ch (Front)", "", "set audio-channels \"7.0(front)\"", function() return stateAudChannel("7.0(front)") end, false},
            {RADIO, "7.1ch", "", "set audio-channels \"7.1(alsa)\"", function() return stateAudChannel("7.1(alsa)") end, false},
            {RADIO, "7.1ch (Alt.)", "", "set audio-channels \"7.1\"", function() return stateAudChannel("7.1") end, false},
            {RADIO, "7.1ch (Wide)", "", "set audio-channels \"7.1(wide)\"", function() return stateAudChannel("7.1(wide)") end, false},
            {RADIO, "7.1ch (Side)", "", "set audio-channels \"7.1(wide-side)\"", function() return stateAudChannel("7.1(wide-side)") end, false},
            {RADIO, "7.1ch (Back)", "", "set audio-channels \"7.1(rear)\"", function() return stateAudChannel("7.1(rear)") end, false},
            {RADIO, "8.0ch (Octagonal)", "", "set audio-channels \"octagonal\"", function() return stateAudChannel("octagonal") end, false},
        },
        
        subtitle_menu = {
            {CASCADE, "Track", "subtrack_menu", "", "", false},
            {SEP},
            {CASCADE, "Alightment", "subalign_menu", "", "", false},
            {CASCADE, "Position", "subpos_menu", "", "", false},
            {CASCADE, "Scale", "subscale_menu", "", "", false},
            {SEP},
            {CASCADE, "Sync", "subsync_menu", "", "", false},
        },
        
        -- Use function to return list of Subtitle Tracks
        subtrack_menu = subTrackMenu(),
        
        subalign_menu = {
            {COMMAND, "Select Next", "", "cycle-values sub-align-y \"top\" \"bottom\"", "", false},
            {SEP},
            {RADIO, "Top", "", "set sub-align-y \"top\"", function() return stateSubAlign("top") end, false},
            {RADIO, "Bottom", "","set sub-align-y \"bottom\"", function() return stateSubAlign("bottom") end, false},
        },
        
        subpos_menu = {
            {COMMAND, "Reset", "Alt+S", "no-osd set sub-pos 100 ; no-osd set sub-scale 1 ; show-text \"Subtitle Position - Reset\"", "", false},
            {SEP},
            {COMMAND, "+" .. opt.subPos .. "%", "S", "add sub-pos " .. opt.subPos, "", false},
            {COMMAND, "-" .. opt.subPos .. "%", "W", "add sub-pos -" .. opt.subPos, "", false},
            {SEP},
            {RADIO, "Display on Letterbox", "", "set image-subs-video-resolution \"no\"", function() return stateSubPos(false) end, false},
            {RADIO, "Display in Video", "", "set image-subs-video-resolution \"yes\"", function() return stateSubPos(true) end, false},
        },
        
        subscale_menu = {
            {COMMAND, "Reset", "", "no-osd set sub-pos 100 ; no-osd set sub-scale 1 ; show-text \"Subtitle Position - Reset\"", "", false},
            {SEP},
            {COMMAND, "+" .. opt.subScale .. "%", "Shift+L", "add sub-scale " .. (opt.subScale / 100), "", false},
            {COMMAND, "-" .. opt.subScale .. "%", "Shift+K", "add sub-scale -" .. (opt.subScale / 100), "", false},
        },
        
        subsync_menu = {
            {COMMAND, "Reset", "Q", "no-osd set sub-delay 0 ; show-text \"Subtitle Delay - Reset\"", "", false},
            {SEP},
            {COMMAND, "+" .. opt.subSync .. " ms", "D", "add sub-delay +" .. (opt.subSync / 1000) .. "", "", false},
            {COMMAND, "-" .. opt.subSync .. " ms", "A", "add sub-delay -" .. (opt.subSync / 1000) .. "", "", false},
        },
        
        tools_menu = {
            {CASCADE, "Playlist", "playlist_menu", "", "", false},
            {COMMAND, "Find Subtitle (Subit)", "", "script-binding subit", "", false},
            {COMMAND, "Playback Information", "Tab", "script-binding display-stats-toggle", "", false},
        },
        
        playlist_menu = {
            {COMMAND, "Show", "l", "script-binding showplaylist", "", false},
            {SEP},
            {COMMAND, "Open", "", "script-binding open_playlist_zenity", "", false},
            {COMMAND, "Save", "", "script-binding saveplaylist", "", false},
            {COMMAND, "Regenerate", "", "script-binding loadfiles", "", false},
            {COMMAND, "Clear", "Shift+L", "playlist-clear", "", false},
            {SEP},
            {COMMAND, "Append File", "", "script-binding append_files_zenity", "", false},
            {COMMAND, "Append URL", "", "script_binding append_url_zenity", "", false},
            {COMMAND, "Remove", "", "playlist-remove current", "", false},
            {SEP},
            {COMMAND, "Move Up", "", function() movePlaylist("up") end, "", function() return (propNative("playlist-count") < 2) and true or false end},
            {COMMAND, "Move Down", "", function() movePlaylist("down") end, "", function() return (propNative("playlist-count") < 2) and true or false end},
            {SEP},
            {CHECK, "Shuffle", "", "cycle shuffle", function() return propNative("shuffle") end, false},
            {CHECK, "Repeat", "", "cycle-values loop-playlist \"inf\" \"no\"", function() return stateLoop() end, false},
        },
        
        window_menu = {
            {CASCADE, "Stays on Top", "staysontop_menu", "", "", false},
            {CHECK, "Remove Frame", "", "cycle border", function() return not propNative("border") end, false},
            {SEP},
            {COMMAND, "Toggle Fullscreen", "", "cycle fullscreen", "", false},
            {COMMAND, "Enter Fullscreen", "", "set fullscreen \"no\"", "", false},
            {COMMAND, "Exit Fullscreen", "", "set fullscreen \"yes\"", "", false},
            {SEP},
            {COMMAND, "Close", "Ctrl+W", "quit", "", false},
        },
        
        staysontop_menu = {
            {COMMAND, "Select Next", "", "cycle ontop", "", false},
            {SEP},
            {RADIO, "Off", "", "set ontop \"yes\"", function() return stateOnTop(false) end, false},
            {RADIO, "On", "", "set ontop \"no\"", function() return stateOnTop(true) end, false},
        },        
    }
    
    -- This check ensures that all tables of data without SEP in them are 6 items long.
    for key, value in pairs(context_menu) do
        if (type(key) == "number") then
            for i = 1, #context_menu do
                if (context_menu[i][1] ~= SEP) then
                    if (#context_menu[i] ~= 6) then  mpdebug("Menu item at index of " .. i .. " is " .. #context_menu .. "items long") end
                end
            end
        else
            for i = 1, #value do
                if (value[i][1] ~= SEP) then
                    if (#value[i] ~= 6) then mpdebug("Menu item at index of " .. i .. " is " .. #value[i] .. " items long for: " .. key) end
                end
            end
        end
    end
end)

local interpreter = "wish";  -- tclsh/wish/full-path
local menuscript = mp.find_config_file("scripts/mpvcontextmenu.tcl")

--[[ ************ CONFIG: end ************ ]]--

-- In addition to what's passed above, also send these (prefixed before the other items). We'll
-- add these programattically, so no need to add items to the arrays/tables.
--
-- Current Menu - play_menu, context_menu, etc.
-- Menu Index - This is the array/table index of the Current Menu, so we can use the Index in
-- concert with the Current Menu to get the command, e.g. context_menu["play_menu"][1][4] for
-- the command stored under the first menu item in the Play menu.

local function create_menu(menu, menuName, x, y)
    local mousepos = {}
    mousepos.x, mousepos.y = mp.get_mouse_pos()
    if (x == -1) then x = tostring(mousepos.x) end
    if (y == -1) then y = tostring(mousepos.y) end
    -- For the first run, we'll send the name of the base menu after the x/y
    local args = {x, y, menuName, "", "", "", ""}
    
    -- We use this function to make sure we get the values from functions, etc.
    local function argType(argVal)
        if (type(argVal) == "function") then argVal = argVal() end
        
        -- Check for nil values and warn here
        if (argVal == nil) then mpdebug ("Found a nil value") end
        
        if (type(argVal) == "boolean") then argVal = tostring(argVal)
        else argval = (type(argVal) == "string") and argVal or ""
        end
        
        return argVal
    end
    
    -- Add general args to the list
    local function addArgs(argList)
        for i = 1, #argList do
            if (i == 1) then
                argList[i] = argType(argList[i])
                if (argList[i] == SEP) then
                    args[#args+1] = SEP
                    for iter = 1, 4 do
                        args[#args+1] = ""
                    end
                else
                    args[#args+1] = argList[i]
                end
            else
                if not (i == 4) then args[#args+1] = argType(argList[i]) end
            end
        end
    end
    
    -- Add menu change args. Since we're provided a list of menu names, we can use the length
    -- of the table to add the args as necessary
    local function menuChange(menuNames)
        local emptyMenus = 6
        args[#args+1] = "changemenu"
        emptyMenus = emptyMenus - #menuNames
        -- Add the menu names
        for iter = 1, #menuNames do
            args[#args+1] = menuNames[iter]
        end
        -- Add the empty values
        for iter = 1, emptyMenus do
            args[#args+1] = ""
        end
    end
    
    -- Add a cascade menu (the logic for attaching is done in the Tcl script)
    local function addCascade(label, state)
        args[#args+1] = CASCADE
        args[#args+1] = (argType(label) ~= emptyStr) and argType(label) or ""
        for iter = 1, 4 do
            args[#args+1] = ""
        end
        args[#args+1] = (argType(state) ~= emptyStr) and argType(state) or ""
    end
    
    -- Recurse through the menu's and add them with their submenu's as arguments to be sent
    -- to the Tcl script to parse. Menu's can only be 5 levels deep. As stated, this function
    -- is recursive and calls itself, changing and removing objects as needs be. This
    local menuNames = {}
    local curMenu = {}
    local stopCreate = false
    function buildMenu(mName, mLvl)
        if not (mLvl > 6) then
            menuNames[mLvl] = mName
            if (mName == "context_menu") then curMenu[mLvl] = menu
            else curMenu[mLvl] = menu[mName] end
            
            for i = 1, #curMenu[mLvl] do
                if (curMenu[mLvl][i][1] == CASCADE) then
                    -- Set our sub menu names and objects
                    menuNames[mLvl+1] = curMenu[mLvl][i][3]
                    curMenu[mLvl+1] = menu[menuNames[mLvl+1]]
                    menuChange(menuNames)
                    -- Recurse in and build again
                    buildMenu(menuNames[mLvl+1], (mLvl + 1))
                    -- Add the cascade
                    addCascade(curMenu[mLvl][i][2], curMenu[mLvl][i][6])
                    -- Remove the current table and menuname as we're done with that menu
                    table.remove(curMenu, (mLvl + 1))
                    table.remove(menuNames, (mLvl + 1))
                    -- With the menuname removed, the count is smaller and it pulls
                    -- us one menu back to continue from the previous menu.
                    menuChange(menuNames)
                else
                    args[#args+1] = mName
                    args[#args+1] = i
                    addArgs(curMenu[mLvl][i])
                end
            end
        else
            -- We only pass sets of seven values when changing menus, minus 1 for the initial
            -- "menuchange" value, 1 for the context_menu, leaving 5 more, for 6 total. This
            -- also stops infinitely recursive cascades.
            mp.osd_message("Too many menu levels. No more than 6 menu levels total.")
            stopCreate = true
            do return end
        end
    end

    buildMenu(menuName, 1)
    
    -- Stop building the menu if there was an issue with too many menu levels since it'll just
    -- cause problems
    if (stopCreate == true) then do return end end
    
    local argList = args[1]
    for i = 2, #args do
        argList = argList .. "|" .. args[i]
    end
    
    local cmdArgs = {interpreter, menuscript, argList}
    
    local retVal = utils.subprocess({
        args = cmdArgs,
        cancellable = true
    })
    
    if (retVal.status ~= 0) then
        mp.osd_message("Possible error in mpvcontextmenu.tcl")
        return
    end

    info("ret: " .. retVal.stdout)
    local response = utils.parse_json(retVal.stdout)
    response.menuname = tostring(response.menuname)
    response.index = tonumber(response.index)
    if (response.index == -1) then
        info("Context menu cancelled")
        return
    end
    
    local respMenu = (response.menuname == menuName) and menu or menu[response.menuname]
    local menuIndex = response.index
    local menuItem = respMenu[menuIndex]
    if (not (menuItem and menuItem[4])) then
        mp.msg.error("Unknown menu item index: " .. tostring(response.index))
        return
    end

    -- Run the command
    if (type(menuItem[4]) == "string") then
        mp.command(menuItem[4])
    else
        menuItem[4]()
    end
end

mp.register_script_message("mpv_context_menu", function()
    create_menu(context_menu, "context_menu", -1, -1)
end)
