--[[ *************************************************************
 * Context menu for mpv using Tcl/Tk.
 * Originally by Avi Halachmi (:avih) https://github.com/avih
 * Extended by Thomas Carmichael (carmanught) https://github.com/carmanaught
 * 
 * Features:
 * - Comprehensive sub-menus providing access to various mpv functionality
 * - Dynamic menu items and commands, disabled items, separators.
 * - Reasonably well behaved/integrated considering it's an external application.
 * 
 * TODO:
 * - Implement functionality for some of the items that will require a file picker dialog
 *   or the like (prefer Zenity, but consider KDialog also)
 * - Possibly different menus for different bindings or states? Perhaps simply better
 *   handling of multiple file types (beyond video) and ensuring correct menus appear.
 *
 * Setup:
 * - Make sure Tcl/Tk is installed and `wish` is accessible and works.
 *   - Alternatively, configure `interpreter` below to `tclsh`, which may work smoother.
 *   - For windows, download a zip from http://www.tcl3d.org/html/appTclkits.html
 *     extract and then rename to wish.exe and put it at the path or at the mpv.exe dir.
 *     - Or, tclsh/wish from git/msys2(mingw) works too - set `interpreter` below.
 * - Put mpvcontextmenu.lua (this file) and mpvcontextmenu.tcl at the mpv scripts dir.
 * - Add a key/mouse binding at input.conf, e.g. "MOUSE_BTN2 script_message mpv_context_menu"
 * - Once it works, configure the context_menu items below to your liking.
 *
 * 2017-02-02 - Version 0.1 - Initial version (avih)
 * 2017-07-19 - Version 0.2 - Extensive rewrite (carmanught)
 * 
 ***************************************************************
--]]
local langcodes = require "langcodes"
local verbose = false  -- true -> Dump console messages also without -v
function info(x) mp.msg[verbose and "info" or "verbose"](x) end
function mpdebug(x) mp.msg.info(x) end -- For printing other debug without verbose

function noop() end
local propNative = mp.get_property_native
local Sep = "separator"
local Cascade = "cascade"
local Command = "command"
local Check = "checkbutton"
local Radio = "radiobutton"
local AB = "ab-button"
local stateA = "A"
local stateB = "B"

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
            table.insert(editionMenuVal, {Radio, editionTitle, "", editionCommand, function() return checkEdition(editionNum) end, false})
        end
    else
        table.insert(editionMenuVal, {Command, "No Editions", "", "", "", true})
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
        {Command, "Previous", "PgUp", "no-osd add chapter -1", "", false},
        {Command, "Next", "PgDown", "no-osd add chapter 1", "", false},
    }
    if not (chapterCount == 0) then
        for chapterNum=0, (chapterCount - 1), 1 do
            local chapterTitle = propNative("chapter-list/" .. chapterNum .. "/title")
            if not (chapterTitle) then chapterTitle = "Chapter " .. (chapterNum + 1) end
            
            local chapterCommand = "set chapter " .. chapterNum
            if (chapterNum == 0) then table.insert(chapterMenuVal, {Sep}) end
            table.insert(chapterMenuVal, {Radio, chapterTitle, "", chapterCommand, function() return checkChapter(chapterNum) end, false})
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
            table.insert(vidTrackMenuVal, {Radio, vidTrackTitle, "", vidTrackCommand, function() return checkTrack(vidTrackNum) end, false})
        end
    else
        table.insert(vidTrackMenuVal, {Radio, "No Video Tracks", "", "", "", true})
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
         {Command, "Open File", "", "", "", true},
         {Command, "Auto-load File", "", "", "", true},
         {Command, "Reload File", "", "", "", true},
         {Sep},
         {Command, "Select Next", "Ctrl+A", "cycle audio", "", false},
    }
    if not (#audTrackCount == 0) then
        for i = 1, (#audTrackCount), 1 do
            local audTrackNum = audTrackCount[i]
            local audTrackID = propNative("track-list/" .. audTrackNum .. "/id")
            local audTrackTitle = propNative("track-list/" .. audTrackNum .. "/title")
            local audTrackLang = propNative("track-list/" .. audTrackNum .. "/lang")
            -- Convert ISO 639-1/2 codes
            if not (audTrackLang == nil) then audTrackLang = getLang(audTrackLang) and getLang(audTrackLang) or audTrackLang end
            

            if (audTrackTitle) then audTrackTitle = audTrackTitle .. " (" .. audTrackLang .. ")"
            elseif (audTrackLang) then audTrackTitle = audTrackLang
            else audTrackTitle = "Audio Track " .. i end
            
            local audTrackCommand = "set aid " .. audTrackID
            if (i == 1) then
                table.insert(audTrackMenuVal, {Command, "Select None", "", "set aid 0", "", false})
                table.insert(audTrackMenuVal, {Sep})
            end
            table.insert(audTrackMenuVal, {Radio, audTrackTitle, "", audTrackCommand, function() return checkTrack(audTrackNum) end, false})
            if (i == #audTrackCount) then
            
            end
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
        {Command, "Open File", "(Shift+F)", "", "", true},
        {Command, "Auto-load File", "", "", "", true},
        {Command, "Reload File", "(Shift+R)", "", "", true},
        {Command, "Clear File", "", "", "", true},
        {Sep},
        {Command, "Select Next", "Shift+N", "cycle sub", "", false},
        {Command, "Select Previous", "Ctrl+Shift+N", "cycle sub down", "", false},
        {Check, function() return subVisLabel() end, "V", "cycle sub-visibility", function() return not propNative("sub-visibility") end, false},
    }
    if not (#subTrackCount == 0) then
        for i = 1, (#subTrackCount), 1 do
            local subTrackNum = subTrackCount[i]
            local subTrackID = propNative("track-list/" .. subTrackNum .. "/id")
            local subTrackTitle = propNative("track-list/" .. subTrackNum .. "/title")
            local subTrackLang = propNative("track-list/" .. subTrackNum .. "/lang")
            -- Convert ISO 639-1/2 codes
            if not (subTrackLang == nil) then subTrackLang = getLang(subTrackLang) and getLang(subTrackLang) or subTrackLang end
            
            if (subTrackTitle) then subTrackTitle = subTrackTitle .. " (" .. subTrackLang .. ")"
            elseif (subTrackLang) then subTrackTitle = subTrackLang
            else subTrackTitle = "Subtitle Track " .. i end
            
            local subTrackCommand = "set sid " .. subTrackID
            if (i == 1) then
                table.insert(subTrackMenuVal, {Command, "Select None", "", "set sid 0", "", false})
                table.insert(subTrackMenuVal, {Sep})
            end
            table.insert(subTrackMenuVal, {Radio, subTrackTitle, "", subTrackCommand, function() return checkTrack(subTrackNum) end, false})
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

-- Aspect Ratio radio item check and labeling
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

-- Video Rotate radio item check and labeling
local function stateRotate(rotateVal)
    local rotateState, rotateCur = false, propNative("video-rotate")
    if (rotateVal == rotateCur) then rotateState = true end
    return rotateState
end

-- Video Alignment radio item checks and labeling
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

-- Deinterlacing radio item check and labeling
local function stateDeInt(deIntVal)
    local deIntState, deIntCur = false, propNative("deinterlace")
    if (deIntVal == deIntCur) then deIntState = true end
    return deIntState
end

-- Mute label
local function muteLabel() return propNative("mute") and "Un-mute" or "Mute" end

-- Subtitle Alignment radio item check and labeling
local function stateSubAlign(subAlignVal)
    local subAlignState, subAlignCur = false, propNative("sub-align-y")
    if (subAlignVal == subAlignCur) then subAlignState = true end
    return subAlignState
end

-- Subtitle Position radio item check and labeling
local function stateSubPos(subPosVal)
    local subPosState, subPosCur = false, propNative("image-subs-video-resolution")
    if (subPosVal == subPosCur) then subPosState = true end
    return subPosState
end

--[[ ************ CONFIG: start ************ ]]--

local context_menu = {}

-- Format for object arrays
-- {Item Type, Label, Accelerator, Command, Item State, Item Disable}

-- Item Type - The type of item, e.g. Cascade, Command, Checkbutton, Radiobutton, etc
-- Label - The label for the item
-- Accelerator - The text shortcut/accelerator for the item
-- Command - This is the command to run when the item is clicked
-- Item State - The state of the item (selected/unselected). A/B Repeat is a special case.
-- Item Disable - Whether to disable

-- Item Type, Label and Accelerator should all evaluate to strings as a result of the return
-- from a function or be strings themselves.
-- Command can be a function or string, this will be handled after a click.
-- Item State and Item Disable should normally be boolean but can be a string for A/B Repeat

-- DO NOT create the menu tables until AFTER the file has loaded as we're unable to
-- dynamically create menus if it tries to build the table before the file is loaded.
-- A prime example is the chapter-list or track-list values, which are unavailable until
-- the file has been loaded.

mp.register_event("file-loaded", function()
    context_menu = {
        open_menu = {
            -- Some of these to be changed when I've developed some Zenity stuff
            {Command, "File", "Ctrl+F", "script-binding navigator", "", false},
            {Command, "Folder", "(Unbound)", "", "", true},
            {Command, "URL", "", "", "", true},
            {Command, "DVD", "", "", "", true},
            {Command, "Bluray", "", "", "", true},
            {Command, "From Clipboard", "(Unbound)", "", "", true},
            {Sep},
            {Command, "Recent", "", "", "", true}, -- No menu yet
        },
        
        speed_menu = {
            {Command, "Reset", "Backspace", "no-osd set speed 1.0 ; show-text \"Play Speed - Reset\"", "", false},
            {Sep},
            {Command, "+5%", "=", "multiply speed 1.05", "", false},
            {Command, "-5%", "-", "multiply speed 0.95", "", false},
        },
        
        abrepeat_menu = {
            {AB, "Set/Clear A-B Loop", "R", "ab-loop", function() return stateABLoop() end, false},
            {Check, "Toggle Infinite Loop", "Shift+R", "cycle-values loop-file \"inf\" \"no\"", propNative("loop-file"), false},
            -- I'll look at this later with Zenity stuff
            {Command, "Set Loop Points...", "", "", "", true},
        },
        
        seek_menu = {
            {Command, "Beginning", "Ctrl+Home", "no-osd seek 0 absolute", "", false},
            {Command, "Previous Playback", "", "", "", true},
            {Sep},
            {Command, "+5 Sec", "Right", "no-osd seek 5", "", false},
            {Command, "-5 Sec", "Left", "no-osd seek -5", "", false},
            {Command, "+30 Sec", "Up", "no-osd seek 30", "", false},
            {Command, "-30 Sec", "Down", "no-osd seek -30", "", false},
            {Command, "+60 Sec", "End", "no-osd seek 60", "", false},
            {Command, "-60 Sec", "Home", "no-osd seek -60", "", false},
            {Sep},
            {Command, "Previous Frame", "Alt+Left", "frame-back-step", "", false},
            {Command, "Next Frame", "Alt+Right", "frame-step", "", false},
            {Command, "Next Black Frame", "Alt+b", "script-binding skip_scene", "", false},
            {Sep},
            {Command, "Previous Subtitle", "", "no-osd sub-seek -1", "", false},
            {Command, "Current Subtitle", "", "no-osd sub-seek 0", "", false},
            {Command, "Next Subtitle", "", "no-osd sub-seek 1", "", false},
        },
        
        -- Use functions returning arrays/tables, since we don't need these menus if there
        -- aren't any editions or any chapters to seek through.
        edition_menu = editionMenu(),
        chapter_menu = chapterMenu(),
        
        play_menu = {
            {Command, "Play/Pause", "Space", "cycle pause", "", false},
            {Command, "Stop", "Ctrl+Shift+Space", "stop", "", false},
            {Sep},
            {Command, "Previous", "<", "playlist-prev", "", false},
            {Command, "Next", ">", "playlist-next", "", false},
            {Sep},
            {Cascade, "Speed", "speed_menu", "", "", false},
            {Cascade, "A-B Repeat", "abrepeat_menu", "", "", false},
            {Sep},
            {Cascade, "Seek", "seek_menu", "", "", false},
            {Cascade, "Title/Edition", "edition_menu", "", "", function() return enableEdition() end},
            {Cascade, "Chapter", "chapter_menu", "", "", function() return enableChapter() end},
            {Sep},
            {Command, "Streaming Format", "", "", "", true}, -- No menu yet
            {Command, "Show State", "", "", "", true}, -- No menu yet
        },
        
        -- Use function to return list of Video Tracks
        vidtrack_menu = vidTrackMenu(),
        
        screenshot_menu = {
            {Command, "Screenshot", "Ctrl+S", "async screenshot", "", false},
            {Command, "Screenshot (No Subs)", "Alt+S", "async screenshot video", "", false},
            {Command, "Screenshot (Subs/OSD/Scaled)", "", "async screenshot window", "", false},
            {Command, "Screenshot Tool", "", "", "", true},
        },
        
       aspect_menu = {
            {Command, "Reset", "Ctrl+Shift+R", "no-osd set video-aspect \"-1\" ; no-osd set video-aspect \"-1\" ; show-text \"Video Aspect Ratio - Reset\"", "", false},
            {Command, "Select Next", "", "cycle-values video-aspect \"4:3\" \"16:10\" \"16:9\" \"1.85:1\" \"2.35:1\" \"-1\" \"-1\"", "", false},
            {Sep},
            {Command, "Same as Window", "", "", "", true},
            {Radio, "4:3 (TV)", "", "set video-aspect \"4:3\"", function() return stateRatio("4:3") end, false},
            {Radio, "16:10 (Wide Monitor)", "", "set video-aspect \"16:10\"", function() return stateRatio("16:10") end, false},
            {Radio, "16:9 (HDTV)", "", "set video-aspect \"16:9\"", function() return stateRatio("16:9") end, false},
            {Radio, "1.85:1 (Wide Vision)", "", "set video-aspect \"1.85:1\"", function() return stateRatio("1.85:1") end, false},
            {Radio, "2.35:1 (CinemaScope)", "", "set video-aspect \"2.35:1\"", function() return stateRatio("2.35:1") end, false},
            {Sep},
            {Command, "+0.001", "Ctrl+Shift+A", "add video-aspect 0.001", "", false},
            {Command, "-0.001", "Ctrl+Shift+D", "add video-aspect -0.001", "", false},
        },
        
        zoom_menu = {
            {Command, "Reset", "Shift+R", "no-osd set panscan 0 ; show-text \"Pan/Scan - Reset\"", "", false},
            {Sep},
            {Command, "+0.1 %", "Shift+T", "add panscan 0.001", "", false},
            {Command, "-0.1 %", "Shift+G", "add panscan -0.001", "", false},
        },
        
        rotate_menu = {
            {Command, "Reset", "", "set video-rotate \"0\"", "", false},
            {Command, "Select Next", "", "cycle-values video-rotate \"0\" \"90\" \"180\" \"270\"", "", false},
            {Sep},
            {Radio, "0°", "", "set video-rotate \"0\"", function() return stateRotate(0) end, false},
            {Radio, "90°", "", "set video-rotate \"90\"", function() return stateRotate(90) end, false},
            {Radio, "180°", "", "set video-rotate \"180\"", function() return stateRotate(180) end, false},
            {Radio, "270°", "", "set video-rotate \"270\"", function() return stateRotate(270) end, false},
        },
        
        screenpos_menu = {
            {Command, "Reset", "Shift+X", "no-osd set video-pan-x 0 ; no-osd set video-pan-y 0 ; show-text \"Video Pan - Reset\"", "", false},
            {Sep},
            {Command, "Horizontally +0.1%", "Shift+D", "add video-pan-x 0.001", "", false},
            {Command, "Horizontally -0.1%", "Shift+A", "add video-pan-x -0.001", "", false},
            {Sep},
            {Command, "Vertically +0.1%", "Shift+S", "add video-pan-y -0.001", "", false},
            {Command, "Vertically -0.1%", "Shift+W", "add video-pan-y 0.001", "", false},
        },
        
        screenalign_menu = {
            -- Y Values: -1 = Top, 0 = Vertical Center, 1 = Bottom
            -- X Values: -1 = Left, 0 = Horizontal Center, 1 = Right
            {Radio, "Top", "", "set video-align-y -1", function() return stateAlign("y",-1) end, false},
            {Radio, "Vertical Center", "", "set video-align-y 0", function() return stateAlign("y",0) end, false},
            {Radio, "Bottom", "", "set video-align-y 1", function() return stateAlign("y",1) end, false},
            {Sep},
            {Radio, "Left", "", "set video-align-x -1", function() return stateAlign("x",-1) end, false},
            {Radio, "Horizontal Center", "", "set video-align-x 0", function() return stateAlign("x",0) end, false},
            {Radio, "Right", "", "set video-align-x 1", function() return stateAlign("x",1) end, false},
        },
        
        deint_menu = {
            {Command, "Toggle", "Ctrl+D", "cycle deinterlace", "", false},
            {Command, "Auto", "", "set deinterlace \"auto\"", "", false},
            {Sep},
            {Radio, "Off", "", "set deinterlace \"no\"", function() return stateDeInt(false) end, false},
            {Radio, "On", "", "set deinterlace \"yes\"", function() return stateDeInt(true) end, false},
        },
        
        color_menu = {
            {Command, "Color Editor", "", "", "", true},
            {Command, "Reset", "O", "no-osd set brightness 0 ; no-osd set contrast 0 ; no-osd set hue 0 ; no-osd set saturation 0 ; show-text \"Colors - Reset\"", "", false},
            {Sep},
            {Command, "Brightness +1%", "T", "add brightness 1", "", false},
            {Command, "Brightness -1%", "G", "add brightness -1", "", false},
            {Command, "Contrast +1%", "Y", "add contrast 1", "", false},
            {Command, "Contrast -1%", "H", "add contrast -1", "", false},
            {Command, "Saturation +1%", "U", "add saturation 1", "", false},
            {Command, "Saturation -1%", "J", "add saturation -1", "", false},
            {Command, "Hue +1%", "I", "add hue 1", "", false},
            {Command, "Hue -1%", "K", "add hue -1", "", false},
            {Command, "Red +1%", "", "", "", true},
            {Command, "Red -1%", "", "", "", true},
            {Command, "Green +1%", "", "", "", true},
            {Command, "Green -1%", "", "", "", true},
            {Command, "Blue +1%", "", "", "", true},
            {Command, "Blue -1%", "", "", "", true},
        },
        
        video_menu = {
            {Cascade, "Track", "vidtrack_menu", "", "", function() return enableVidTrack() end},
            {Sep},
            {Cascade, "Take Screenshot", "screenshot_menu", "", "", false},
            {Command, "Make Video Clip", "", "", "", true}, -- No menu yet
            {Sep},
            {Cascade, "Aspect Ratio", "aspect_menu", "", "", false},
            {Command, "Crop", "", "", "", true}, -- No menu yet
            {Cascade, "Zoom", "zoom_menu", "", "", true},
            {Cascade, "Rotate", "rotate_menu", "", "", true},
            {Cascade, "Screen Position", "screenpos_menu", "", "", false},
            {Cascade, "Screen Alignment", "screenalign_menu", "", "", false},
            {Sep},
            {Command, "Color Space", "", "", "", true}, -- No menu yet
            {Command, "Color Range", "", "", "", true}, -- No menu yet
            {Sep},
            {Command, "Quality Preset", "", "", "", true}, -- No menu yet
            {Command, "Texture Format", "", "", "", true}, -- No menu yet
            {Command, "Chroma Upscaler", "", "", "", true}, -- No menu yet
            {Command, "Interpolater", "", "", "", true}, -- No menu yet
            {Command, "Interpolater (Downscale)", "", "", "", true}, -- No menu yet
            {Command, "High Quality Scaling", "", "", "", true}, -- No menu yet
            {Command, "Dithering", "", "", "", true}, -- No menu yet
            {Sep},
            {Command, "Motion Smoothing", "", "", "", true}, -- No menu yet
            {Cascade, "Deinterlacing", "deint_menu", "", "", false},
            {Command, "Filter", "", "", "", true}, -- No menu yet
            {Cascade, "Adjust Color", "color_menu", "", "", false},
        },
        -- Use function to return list of Audio Tracks
        audtrack_menu = audTrackMenu(),
        
        audsync_menu = {
            {Command, "Reset", "\\", "no-osd set audio-delay 0 ; show-text \"Audio Sync - Reset\"", "", false},
            {Sep},
            {Command, "+0.1 Sec", "]", "add audio-delay 0.100", "", false},
            {Command, "-0.1 Sec", "[", "add audio-delay -0.100", "", false},
        },
        
        volume_menu = {
            {Check, function() return muteLabel() end, "", "cycle mute", function() return propNative("mute") end, false},
            {Sep},
            {Command, "+2%", "Shift+Up", "add volume 2", "", false},
            {Command, "-2%", "Shift+Down", "add volume -2", "", false},
        },
        
        audio_menu = {
            {Cascade, "Track", "audtrack_menu", "", "", false},
            {Cascade, "Sync", "audsync_menu", "", "", false},
            {Sep},
            {Cascade, "Volume", "volume_menu", "", "", false},
            {Command, "Amp", "", "", "", true}, -- No menu yet
            {Command, "Equalizer", "", "", "", true}, -- No menu yet
            {Command, "Channel Layout", "", "", "", true}, -- No menu yet
            {Sep},
            {Command, "Visualization", "", "", "", true}, -- No menu yet
            -- Need to figure out how to apply/remove filters to make the Normalizer toggle work
            -- Need to add function here to check the status of normalization
            {Check, "Normalizer", "N", "", false, true},
            {Check, "Temp Scalar", "", "", false, true},
        },
        -- Use function to return list of Subtitle Tracks
        subtrack_menu = subTrackMenu(),
        
        subalign_menu = {
            {Command, "Select Next", "", "cycle-values sub-align-y \"top\" \"bottom\"", "", false},
            {Sep},
            {Radio, "Top", "", "set sub-align-y \"top\"", function() return stateSubAlign("top") end, false},
            {Radio, "Bottom", "","set sub-align-y \"bottom\"", function() return stateSubAlign("bottom") end, false},
        },
        
        subpos_menu = {
            {Command, "Reset", "Alt+S", "no-osd set sub-pos 100 ; no-osd set sub-scale 1 ; show-text \"Subitle Position - Reset\"", "", false},
            {Sep},
            {Command, "+1%", "S", "add sub-pos 1", "", false},
            {Command, "-1%", "W", "add sub-pos -1", "", false},
            {Sep},
            {Radio, "Display on Letterbox", "", "set image-subs-video-resolution \"no\"", function() return stateSubPos(false) end, false},
            {Radio, "Display in Video", "", "set image-subs-video-resolution \"yes\"", function() return stateSubPos(true) end, false},
        },
        
        subscale_menu = {
            {Command, "Reset", "", "no-osd set sub-pos 100 ; no-osd set sub-scale 1 ; show-text \"Subitle Position - Reset\"", "", false},
            {Sep},
            {Command, "+1%", "Shift+L", "add sub-scale 0.01", "", false},
            {Command, "-1%", "Shift+K", "add sub-scale -0.01", "", false},
        },
        
        subsync_menu = {
            {Command, "Reset", "Q", "no-osd set sub-delay 0 ; show-text \"Subtitle Delay - Reset\"", "", false},
            {Sep},
            {Command, "+0.1 Sec", "D", "add sub-delay +0.1", "", false},
            {Command, "-0.1 Sec", "A", "add sub-delay -0.1", "", false},
            {Sep},
            {Command, "Bring Previous Lines", "", "", "", true},
            {Command, "Bring Next Lines", "", "", "", true},
        },
        
        subtitle_menu = {
            {Cascade, "Track", "subtrack_menu", "", "", false},
            {Sep},
            {Command, "Override ASS", "", "", "", true}, -- No menu yet
            {Cascade, "Alightment", "subalign_menu", "", "", false},
            {Cascade, "Position", "subpos_menu", "", "", false},
            {Cascade, "Scale", "subscale_menu", "", "", false},
            {Sep},
            {Cascade, "Sync", "subsync_menu", "", "", false},
        },
        
        playlist_menu = {
            {Command, "Show", "l", "script-binding showplaylist", "", false},
            {Sep},
            {Command, "Open", "", "", "", true},
            {Command, "Save", "", "script-binding saveplaylist", "", false},
            {Command, "Regenerate", "", "script-binding loadfiles", "", false},
            {Command, "Clear", "Shift+L", "", "", true},
            {Sep},
            {Command, "Append File", "", "", "", true},
            {Command, "Append Folder", "", "", "", true},
            {Command, "Append URL", "", "", "", true},
            {Command, "Remove", "Shift+R", "", "", true},
            {Sep},
            {Command, "Move Up", "", "", "", true},
            {Command, "Move Down", "", "", "", true},
            {Sep},
            -- These following two are checkboxes
            {Check, "Shuffle", "", "", false, true},
            {Check, "Repeat", "", "", false, true},
        },
        
        history_menu = {
            {Command, "Show/Hide", "", "", "", true},
            {Command, "Clear", "", "", "", true},
        },
        
        tools_menu = {
            {Command, "Undo", "", "", "", true},
            {Command, "Redo", "", "", "", true},
            {Sep},
            {Command, "Playlist", "", "", "", true}, -- No menu yet
            -- Not sure if I need this, mpv doesn't really keep a recent history beyond watch_later
            -- config files, which is not quite the same thing.
            {Command, "History", "", "", "", true}, -- No menu yet
            {Command, "Find Subtitle (Subit)", "", "script-binding subit", "", false},
            {Command, "Subitle Viewer", "", "", "", true},
            {Command, "Playback Information", "Tab", "script-binding display-stats-toggle", "", false},
            {Command, "Log Viewer", "", "", "", true},
            {Sep},
            {Command, "Preferences", "", "", "", true},
            {Command, "Reload Skin", "", "", "", true},
            {Sep},
            -- These following two are checkboxes
            {Check, "Auto-exit", "", "", false, true},
            {Check, "Auto-shutdown", "", "", false, true},
        },
        
        staysontop_menu = {
            {Command, "Empty", "", "", "", true},
            {Sep},
            -- Radio buttons
            {Radio, "Off", "", "", false, true},
            {Radio, "Playing", "", "", false, true},
            {Radio, "Always", "", "", false, true},
        },
        
        window_menu = {
            {Cascade, "Stays on Top", "staysontop_menu", "", "", false},
            {Check, "Remove Frame", "", "cycle border", function() return propNative("border") end, true},
            {Sep},
            {Command, "Display Size x10%", "", "", "", true},
            {Command, "Display Size x20%", "", "", "", true},
            {Command, "Display Size x30%", "", "", "", true},
            {Command, "Display Size x40%", "", "", "", true},
            {Command, "Video Size x100%", "", "", "", true},
            {Sep},
            {Command, "Toggle Fullscreen", "", "", "", true},
            {Command, "Enter Fullscreen", "", "", "", true},
            {Command, "Exit Fullscreen", "", "", "", true},
            {Sep},
            {Command, "Maximize", "", "", "", true},
            {Command, "Minimize", "", "", "", true},
            {Command, "Close", "Ctrl+W", "", "", true},
        },
        
        {Cascade, "Open", "open_menu", "", "", false},
        {Sep},
        {Cascade, "Play", "play_menu", "", "", false},
        {Cascade, "Video", "video_menu", "", "", false},
        {Cascade, "Audio", "audio_menu", "", "", false},
        {Cascade, "Subtitle", "subtitle_menu", "", "", false},
        {Sep},
        {Cascade, "Tools", "tools_menu", "", "", false},
        {Cascade, "Window", "window_menu", "", "", false},
        {Sep},
        {Command, "Dismiss Menu", "", noop, "", false},
        {Command, "Quit", "", "quit", "", false},
    }
    
    menulist = {"open_menu", "speed_menu", "abrepeat_menu", "seek_menu", "edition_menu",
        "chapter_menu", "play_menu", "vidtrack_menu", "screenshot_menu", "aspect_menu",
        "zoom_menu", "rotate_menu", "screenpos_menu", "screenalign_menu", "deint_menu",
        "color_menu", "video_menu", "audtrack_menu", "audsync_menu", "volume_menu",
        "audio_menu", "subtrack_menu", "subalign_menu", "subpos_menu", "subscale_menu",
        "subsync_menu", "subtitle_menu", "playlist_menu", "history_menu", "tools_menu",
        "staysontop_menu", "window_menu"
    }
    
    -- This check ensures that all tables of data without Sep in them are 6 items long.
    for i = 1, #menulist do
        if (i == 1) then
            for subi = 1, #context_menu do
                if not (context_menu[subi][1] == Sep) then
                    if (#context_menu[subi] < 6) or (#context_menu[subi] > 6) then
                        mpdebug("Menu item at index of " .. subi .. " is " .. #context_menu .. "items long")
                    end
                end
            end
        end
        local thismenu = menulist[i]
        for subi = 1, #context_menu[thismenu] do
             if not (context_menu[thismenu][subi][1] == Sep) then
                if (#context_menu[thismenu][subi] < 6) or (#context_menu[thismenu][subi] > 6) then
                    mpdebug("Menu item at index of " .. subi .. " is " .. #context_menu[thismenu][subi] .. " items long for: " .. thismenu)
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

local utils = require 'mp.utils'

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
                if (argList[i] == Sep) then
                    args[#args+1] = Sep
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
    
    -- Add menu change args 
    local function menuChange(baseMenu, subMenu, subSubMenu)
        args[#args+1] = "changemenu"
        args[#args+1] = baseMenu
        if (subSubMenu) then
            args[#args+1] = subMenu
            args[#args+1] = subSubMenu
            args[#args+1] = ""
        elseif (subMenu) then
            args[#args+1] = subMenu
            args[#args+1] = subSubMenu
            for iter = 1, 2 do
                args[#args+1] = ""
            end
        else
            for iter = 1, 3 do
                args[#args+1] = ""
            end
        end
    end
    
    -- Add a cascade menu (the logic for attaching is done in the Tcl script)
    local function addCascade(label, state)
        args[#args+1] = Cascade
        args[#args+1] = (argType(label) ~= emptyStr) and argType(label) or ""
        for iter = 1, 4 do
            args[#args+1] = ""
        end
        args[#args+1] = (argType(state) ~= emptyStr) and argType(state) or ""
    end
    
    -- Iterate through the menu's and add them with their submenu's as arguments to be sent
    -- to the Tcl script to parse
    for i = 1, #menu do
        args[#args+1] = menuName
        args[#args+1] = i
        
        if (menu[i][1] == Cascade) then
            subMenuName = menu[i][3]
            subMenu = menu[subMenuName]
            menuChange(menuName, subMenuName)
            
            for subi = 1, #subMenu do
                args[#args+1] = subMenuName
                args[#args+1] = subi
                
                if (subMenu[subi][1] == Cascade) then
                    subSubMenuName = subMenu[subi][3]
                    subSubMenu = menu[subSubMenuName]
                    menuChange(menuName, subMenuName, subSubMenuName)
                    
                    for subsubi = 1, #subSubMenu do
                        args[#args+1] = subSubMenuName
                        args[#args+1] = subsubi
                        addArgs(subSubMenu[subsubi])
                    end
                    
                    addCascade(subMenu[subi][2], subMenu[subi][6])
                    args[#args+1] = subMenuName
                    args[#args+1] = subi
                    menuChange(menuName, subMenuName)
                else
                    addArgs(subMenu[subi])
                end
            end
            addCascade(menu[i][2], menu[i][6])
            args[#args+1] = menuName
            args[#args+1] = i
            menuChange(menuName)
        else
            addArgs(menu[i])
        end
    end
    
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
        mp.osd_message("Something happened ...")
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
