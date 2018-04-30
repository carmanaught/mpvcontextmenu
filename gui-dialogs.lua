--
-- Use KDialog/Zenity for various dialogs including:
-- - Opening files (replacing current playlist)
-- - Adding files to the playlist
-- - Opening separate Audio/Subtitle Tracks
-- - Opening URLs
-- - Opening folders (replacing current playlist)
-- - Adding folders to the playlist - Note: This will only resolve the list of files once
--   the playlist entry starts playing
-- 
-- Based on 'kdialog-open-files' (https://gist.github.com/ntasos/d1d846abd7d25e4e83a78d22ee067a22).
--
-- This is intended to be used in concert with mpvcontextmenu, but can be used seperately
-- by specifying script bindings below or in input.conf
-- 
utils = require "mp.utils"

-- Set options
options = require "mp.options"
local opt = {
    -- Dialog preference (kdialog/zenity)
    dialogPref = "",
    -- Standard keybindings
    addFiles = "Ctrl+f",
    addFolder = "Ctrl+g",
    appendFiles = "Ctrl+Shift+f",
    appendFolder = "Ctrl+Shift+g",
    addSubtitle = "F",
    -- These bindings default to nil
    addURL = "",
    openURL = "",
    openPlaylist = "",
    addAudio = "",
}
options.read_options(opt, "gui-dialogs")

-- Specify the paths here if necessary
local KDialog = "kdialog"
local Zenity = "zenity"

local function trim(s)
  return s:match"^()%s*$" and "" or s:match"^%s*(.*%S)"
end

-- File Filters with a list of filetypes - add more types here as desired
local file_filters = {
    video_files = {label="Videos", "3gp", "asf", "avi", "bdm", "bdmv", "clpi", "cpi", "dat", "divx", "dv", "fli", "flv", "ifo", "m2t", "m2ts", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "mpg2", "mpg4", "mpls", "mts", "nsv", "nut", "nuv", "ogg", "ogm", "qt", "rm", "rmvb", "trp", "tp", "ts", "vcd", "vfw", "vob", "webm", "wmv"},

    audio_files = {label="Audio", "aac", "ac3", "aiff", "ape", "flac", "it", "m4a", "mka", "mod", "mp2", "mp3", "ogg", "pcm", "wav", "wma", "xm"},

    image_files = {label="Images", "bmp", "gif", "jpeg", "jpg", "png", "tif", "tiff"},

    playlist_files = {label="Playlists", "cue", "pls", "m3u", "m3u8"},

    subtitle_files = {label="Subtitles", "ass", "smi", "srt", "ssa", "sub", "txt"},

    all_files_zenity = "--file-filter=All Files | *",
    
    all_files_kdialog = "All Files (*)"
}

-- Functions to build file filters and return a value including --file-filter= in it
local function buildFilter(filterName, dialog)
    local filterList = file_filters[filterName]
    local filterArg = ""
    if (dialog == "zenity") then
        filterArg = "--file-filter=" .. filterList["label"] .. " | "
    elseif (dialog == "kdialog") then
        filterArg = filterList["label"] .. " ("
    end
    
    for i = 1, #filterList do
        if not (i == #filterList) then filterArg = filterArg .. "*." .. filterList[i] .. " "
        else filterArg = filterArg .. "*." .. filterList[i] end
    end
    
    if (dialog == "kdialog") then
        filterArg = filterArg .. ")"
    end
    
    return filterArg
end

-- This function includes Video/Audio/Image/Playlist file type all together
local function buildMultimedia(dialog)
    local mediaList = {"video_files", "audio_files", "image_files", "playlist_files"}
    local allMultimedia = ""
    
    if (dialog == "zenity") then
        allMultimedia = "--file-filter=All Types | "
    elseif (dialog == "kdialog") then
        allMultimedia = "All Types" .. " ("
    end
    
    for i = 1, #mediaList do
        local filterList = file_filters[mediaList[i]]
        
        for subi = 1, #filterList do
            if not ((i == #mediaList) and (subi == #filterList)) then
                allMultimedia = allMultimedia .. "*." .. filterList[subi] .. " "
            else allMultimedia = allMultimedia .. "*." .. filterList[subi] end
        end
    end
    
    if (dialog == "kdialog") then
        allMultimedia = allMultimedia .. ")"
    end
    
    return allMultimedia
end

local function createDialog(selType, selMode)
    local focus = utils.subprocess({ args = {"xdotool", "getwindowfocus"} })
    local args, kargs, zargs = {}, {}, {}
    
    -- Get the current path if possible
    if mp.get_property("path") == nil then
        if (dialogPref == "kdialog") then
            directory = "."
        else
            directory = ""
        end
    else
        directory = utils.split_path(utils.join_path(mp.get_property("working-directory"), mp.get_property("path")))
    end
    
    table.insert(kargs, KDialog)
    table.insert(zargs, Zenity)
    
    table.insert(kargs, "--attach=" .. trim(focus.stdout))
    
    if (selType == "url") then
        --KDialog
        table.insert(kargs, "--getopenurl")
        table.insert(kargs, "--title=Open URL")
        --Zenity
        table.insert(zargs, "--entry")
        table.insert(zargs, "--text=Enter URL:")
        table.insert(zargs, "--title=Open URL")
    else
        --KDialog
        table.insert(kargs, "--icon=mpv")
        table.insert(kargs, "--separate-output")
        --Zenity
        table.insert(zargs, "--file-selection")
        table.insert(zargs, "--separator=\n")
        -- Only zenity can be done out here as the filter is another flag to be
        -- passed. kdialog must be done just before the filter items
        table.insert(zargs, "--filename=" .. directory .. "")
        
        if (selType == "file") then
            --KDialog
            table.insert(kargs, "--multiple")
            table.insert(kargs, "--title=Select Files")
            table.insert(kargs, "--getopenfilename")
            table.insert(kargs, "" .. directory .. "")
            table.insert(kargs, buildFilter("video_files", "kdialog") .. "\n" .. buildFilter("audio_files", "kdialog") .. "\n" .. buildFilter("image_files", "kdialog") .. "\n" .. buildFilter("playlist_files", "kdialog") .. "\n" .. buildMultimedia("kdialog") .. "\n" .. file_filters["all_files_kdialog"])
            --Zenity
            table.insert(zargs, "--multiple")
            table.insert(zargs, "--title=Select Files")
            table.insert(zargs, buildFilter("video_files", "zenity"))
            table.insert(zargs, buildFilter("audio_files", "zenity"))
            table.insert(zargs, buildFilter("image_files", "zenity"))
            table.insert(zargs, buildFilter("playlist_files", "zenity"))
            table.insert(zargs, buildMultimedia("zenity"))
            table.insert(zargs, file_filters["all_files_zenity"])
        elseif (selType == "folder") then
            --KDialog
            table.insert(kargs, "--multiple")
            table.insert(kargs, "--title=Select Folders")
            table.insert(kargs, "--getexistingdirectory")
            --Zenity
            table.insert(zargs, "--multiple")
            table.insert(zargs, "--title=Select Folders")
        elseif (selType == "playlist") then
            --KDialog
            table.insert(kargs, "--title=Select Playlist")
            table.insert(kargs, "--getopenfilename")
            table.insert(kargs, "" .. directory .. "")
            table.insert(kargs, buildFilter("playlist_files", "kdialog") .. "\n" .. file_filters["all_files_kdialog"])
            --Zenity
            table.insert(zargs, "--title=Select Playlist")
            table.insert(zargs, buildFilter("playlist_files", "zenity"))
            table.insert(zargs, file_filters["all_files_zenity"])
        elseif (selType == "subtitle") then
            --KDialog
            table.insert(kargs, "--title=Select Subtitle")
            table.insert(kargs, "--getopenfilename")
            table.insert(kargs, "" .. directory .. "")
            table.insert(kargs, buildFilter("subtitle_files", "kdialog") .. "\n" .. file_filters["all_files_kdialog"])
            --Zenity
            table.insert(zargs, "--title=Select Subtitle")
            table.insert(zargs, buildFilter("subtitle_files", "zenity"))
            table.insert(zargs, file_filters["all_files_zenity"])
        elseif (selType == "audio") then
            --KDialog
            table.insert(kargs, "--title=Select Audio")
            table.insert(kargs, "--getopenfilename")
            table.insert(kargs, "" .. directory .. "")
            table.insert(kargs, buildFilter("audio_files", "kdialog") .. "\n" .. file_filters["all_files_kdialog"])
            --Zenity
            table.insert(zargs, "--title=Select Audio")
            table.insert(zargs, buildFilter("audio_files", "zenity"))
            table.insert(zargs, file_filters["all_files_zenity"])
        end
    end
    
    if (opt.dialogPref == "kdialog") then
        args = kargs
    elseif (opt.dialogPref == "zenity") then
        args = zargs
    else
        mp.osd_message("No dialog preference configured for gui-settings.lua")
        return
    end
    
    local dialogResponse = utils.subprocess({
        args = args,
        cancellable = false,
    })
    
    if (dialogResponse.status ~= 0) then return end
    
    local firstFile = true

    if (selMode == "add") then
        if ((selType == "file" ) or (selType == "folder")) then
            for filename in string.gmatch(dialogResponse.stdout, "[^\n]+") do
                mp.commandv("loadfile", filename, firstFile and "replace" or "append")
                firstFile = false
            end
        elseif (selType== "subtitle") then
            for filename in string.gmatch(dialogResponse.stdout, '[^\n]+') do
                mp.commandv('sub-add', filename, 'select')
            end
        elseif (selType== "audio") then
            for filename in string.gmatch(dialogResponse.stdout, '[^\n]+') do
                mp.commandv('audio-add', filename, 'select')
            end
        end
    end
    
    if (selMode == "append") then
        if ((selType == "file" ) or (selType == "folder") or (selType == "url")) then
            for filename in string.gmatch(dialogResponse.stdout, "[^\n]+") do
                if (mp.get_property_number("playlist-count") == 0) then
                    mp.commandv("loadfile", filename, "replace")
                else
                    mp.commandv("loadfile", filename, "append")
                end
                playlistCount = playlistCount + 1
            end
            
            if (selType == "file") then
                mp.osd_message("Added " .. playlistCount .. " file(s) to playlist")
            end
            
            if (selType == "folder") then
                mp.osd_message("Added " .. playlistCount .. " folder(s) to playlist")
            end
        end
    end
    
    if (selMode == "open") then
        if (selType == "url") then
            for filename in string.gmatch(dialogResponse.stdout, '[^\n]+') do
                mp.commandv('loadfile', filename, 'replace')
            end
        elseif (selType== "playlist") then
            for filename in string.gmatch(dialogResponse.stdout, '[^\n]+') do
                mp.commandv('loadfile', filename, 'select')
            end
        end
    end
end

mp.add_key_binding(opt.addFile, "add_files_dialog", function() createDialog("file", "add") end)
mp.add_key_binding(opt.addFolder, "add_folder_dialog", function() createDialog("folder", "add") end)
mp.add_key_binding(opt.appendFiles, "append_files_dialog", function() createDialog("file", "append") end)
mp.add_key_binding(opt.appendFolder, "append_folder_dialog", function() createDialog("folder", "append") end)
mp.add_key_binding(opt.addSubtitle, "add_subtitle_dialog", function() createDialog("subtitle", "add") end)
-- We won't add keybindings for these, but we do want to be able to use them
mp.add_key_binding(opt.addURL, "append_url_dialog", function() createDialog("url", "append") end)
mp.add_key_binding(opt.openURL, "open_url_dialog", function() createDialog("url", "open") end)
mp.add_key_binding(opt.openPlaylist, "open_playlist_dialog", function() createDialog("playlist", "open") end)
mp.add_key_binding(opt.addAudio, "add_audio_dialog", function() createDialog("audio", "add") end)
