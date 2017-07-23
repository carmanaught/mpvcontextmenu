--
-- Use Zenity for various dialogs including:
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
require "mp.options"

local opt = {
    -- Standard keybindings
    addFiles = "Ctrl+f"
    addFolder = "Ctrl+g"
    appendFiles = "Ctrl+Shift+f"
    appendFolder = "Ctrl+Shift+g"
    addSubtitle = "F"
    -- These bindings default to nil
    addURL = nil
    openURL = nil
    openPlaylist = nil
    addAudio = nil
}
read_options(opt)

Zenity = "zenity" -- Specify the path here if necessary
function trim(s)
  return s:match"^()%s*$" and "" or s:match"^%s*(.*%S)"
end

-- File Filters with a list of filetypes - add more types here as desired
local file_filters = {
    video_files = {label="Videos", "3gp", "asf", "avi", "bdm", "bdmv", "clpi", "cpi", "dat", "divx", "dv", "fli", "flv", "ifo", "m2t", "m2ts", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "mpg2", "mpg4", "mpls", "mts", "nsv", "nut", "nuv", "ogg", "ogm", "qt", "rm", "rmvb", "trp", "tp", "ts", "vcd", "vfw", "vob", "webm", "wmv"},

    audio_files = {label="Audio", "aac", "ac3", "aiff", "ape", "flac", "it", "m4a", "mka", "mod", "mp2", "mp3", "ogg", "pcm", "wav", "wma", "xm"},

    image_files = {label="Images", "bmp", "gif", "jpeg", "jpg", "png", "tif", "tiff"},

    playlist_files = {label="Playlists", "cue", "pls", "m3u", "m3u8"},

    subtitle_files = {label="Subtitles", "ass", "smi", "srt", "ssa", "sub", "txt"},

    all_files = "--file-filter=All Files | *"
}

-- Functions to build file filters and return a value including --file-filter= in it
local function buildFilter(filterName)
    local filterList = file_filters[filterName]
    local filterArg = "--file-filter=" .. filterList["label"] .. " | "
    
    for i = 1, #filterList do
        if not (i == #filterList) then filterArg = filterArg .. "*." .. filterList[i] .. " "
        else filterArg = filterArg .. "*." .. filterList[i] end
        
    end
    
    return filterArg
end

-- This function includes Video/Audio/Image/Playlist file type all together
local function buildMultimedia()
    local mediaList = {"video_files", "audio_files", "image_files", "playlist_files"}
    local allMultimedia = "--file-filter=All Types | "
    
    for i = 1, #mediaList do
        local filterList = file_filters[mediaList[i]]
        
        for subi = 1, #filterList do
            if not ((i == #mediaList) and (subi == #filterList)) then
                allMultimedia = allMultimedia .. "*." .. filterList[subi] .. " "
            else allMultimedia = allMultimedia .. "*." .. filterList[subi] end
        end
    end
    
    return allMultimedia
end


function selectFiles()
    local focus = utils.subprocess({ args = {"xdotool", "getwindowfocus"} })
    local args = {}
    
    if mp.get_property("path") == nil then
        directory = ""
    else
        directory = utils.split_path(utils.join_path(mp.get_property("working-directory"), mp.get_property("path")))
    end
    
    args = {Zenity, "--file-selection", "--multiple", "--title=Select Files", "--attach=" .. trim(focus.stdout), "--separator=\n", "--filename=" .. directory .. "", buildFilter("video_files"), buildFilter("audio_files"), buildFilter("image_files"), buildFilter("playlist_files"), buildMultimedia(), file_filters["all_files"]}
    
    local response = utils.subprocess({
        args = args,
        cancellable = false,
    })
    
    return response
end

function selectFolder()
    local focus = utils.subprocess({ args = {"xdotool", "getwindowfocus"} })
    local args = {}
    
    if mp.get_property("path") == nil then
        directory = ""
    else
        directory = utils.split_path(utils.join_path(mp.get_property("working-directory"), mp.get_property("path")))
    end
    
    args = {Zenity, "--file-selection", "--multiple", "--directory", "--title=Select Folders", "--attach=" .. trim(focus.stdout), "--separator=\n", "--filename=" .. directory .. ""}
    
    local response = utils.subprocess({
        args = args,
        cancellable = false,
    })
    
    return response
end

function addFiles()
    local selectResponse = selectFiles()
    if (selectResponse.status ~= 0) then return end
    
    local firstFile = true
    for filename in string.gmatch(selectResponse.stdout, "[^\n]+") do
        mp.commandv("loadfile", filename, firstFile and "replace" or "append")
        firstFile = false
    end
end

function addFolder()
    local selectResponse = selectFolder()
    if (selectResponse.status ~= 0) then return end
    
    local firstFile = true
    for filename in string.gmatch(selectResponse.stdout, "[^\n]+") do
        mp.commandv("loadfile", filename, firstFile and "replace" or "append")
        firstFile = false
    end
end

function appendFiles()
    local playlistCount = 0
    local selectResponse = selectFiles()
    if (selectResponse.status ~= 0) then return end
    
    for filename in string.gmatch(selectResponse.stdout, "[^\n]+") do
        if (mp.get_property_number("playlist-count") == 0) then
            mp.commandv("loadfile", filename, "replace")
        else
            mp.commandv("loadfile", filename, "append")
        end
        playlistCount = playlistCount + 1
    end
    
    mp.osd_message("Added " .. playlistCount .. " file(s) to playlist")
end

function appendFolder()
    local playlistCount = 0
    local selectResponse = selectFolder()
    if (selectResponse.status ~= 0) then return end
    
    for filename in string.gmatch(selectResponse.stdout, "[^\n]+") do
        if (mp.get_property_number("playlist-count") == 0) then
            mp.commandv("loadfile", filename, "replace")
        else
            mp.commandv("loadfile", filename, "append")
        end
        playlistCount = playlistCount + 1
    end
    
    mp.osd_message("Added " .. playlistCount .. " file(s) to playlist")
end

function addURL()
    local focus = utils.subprocess({ args = {"xdotool", "getwindowfocus"} })
    local args = {}
    
    args = {Zenity, "--entry", "--text=Enter URL:", "--title=Append URL", "--attach=" .. trim(focus.stdout)}
    
    local response = utils.subprocess({
        args = args,
        cancellable = false,
    })
    
    if (response.status ~= 0) then return end
    
    for filename in string.gmatch(selectResponse.stdout, "[^\n]+") do
        if (mp.get_property_number("playlist-count") == 0) then
            mp.commandv("loadfile", filename, "replace")
        else
            mp.commandv("loadfile", filename, "append")
        end
        playlistCount = playlistCount + 1
    end
end

function openURL()
    local focus = utils.subprocess({ args = {"xdotool", "getwindowfocus"} })
    local args = {}
    
    args = {Zenity, "--entry", "--text=Enter URL:", "--title=Open URL", "--attach=" .. trim(focus.stdout)}
    
    local response = utils.subprocess({
        args = args,
        cancellable = false,
    })
    
    if (response.status ~= 0) then return end
    
    for filename in string.gmatch(response.stdout, '[^\n]+') do
        mp.commandv('loadfile', filename, 'replace')
    end
end

function openPlaylist()
    local focus = utils.subprocess({ args = {"xdotool", "getwindowfocus"} })
    local args = {}
    
    if mp.get_property("path") == nil then
        directory = ""
    else
        directory = utils.split_path(utils.join_path(mp.get_property("working-directory"), mp.get_property("path")))
    end
    
    args = {Zenity, "--file-selection", "--title=Select Playlist", "--attach=" .. trim(focus.stdout), "--separator=\n", "--filename=" .. directory .. "", buildFilter("playlist_files"), file_filters["all_files"]}
    
    local response = utils.subprocess({
        args = args,
        cancellable = false,
    })
    
    if (response.status ~= 0) then return end
    
    for filename in string.gmatch(response.stdout, '[^\n]+') do
        mp.commandv('loadfile', filename, 'select')
    end
end

function addSubtitle()
    local focus = utils.subprocess({ args = {"xdotool", "getwindowfocus"} })
    local args = {}
    
    if mp.get_property("path") == nil then
        directory = ""
    else
        directory = utils.split_path(utils.join_path(mp.get_property("working-directory"), mp.get_property("path")))
    end
    
    args = {Zenity, "--file-selection", "--title=Select Subtitle", "--attach=" .. trim(focus.stdout), "--separator=\n", "--filename=" .. directory .. "", buildFilter("subtitle_files"), file_filters["all_files"]}
    
    local response = utils.subprocess({
        args = args,
        cancellable = false,
    })
    
    if (response.status ~= 0) then return end
    
    for filename in string.gmatch(response.stdout, '[^\n]+') do
        mp.commandv('sub-add', filename, 'select')
    end
end

function addAudio()
    local focus = utils.subprocess({ args = {"xdotool", "getwindowfocus"} })
    local args = {}
    
    if mp.get_property("path") == nil then
        directory = ""
    else
        directory = utils.split_path(utils.join_path(mp.get_property("working-directory"), mp.get_property("path")))
    end
    
    args = {Zenity, "--file-selection", "--title=Select Audio", "--attach=" .. trim(focus.stdout), "--separator=\n", "--filename=" .. directory .. "", buildFilter("audio_files"), file_filters["all_files"]}
    
    local response = utils.subprocess({
        args = args,
        cancellable = false,
    })
    
    if (response.status ~= 0) then return end
    
    for filename in string.gmatch(response.stdout, '[^\n]+') do
        mp.commandv('audio-add', filename, 'select')
    end
end

mp.add_key_binding(opt.addFile, "add_files_zenity", addFiles)
mp.add_key_binding(opt.addFolder, "add_folder_zenity", addFolder)
mp.add_key_binding(opt.appendFiles, "append_files_zenity", appendFiles)
mp.add_key_binding(opt.appendFolder, "append_folder_zenity", appendFolder)
mp.add_key_binding(opt.addSubtitle, "add_subtitle_zenity", addSubtitle)
-- We won't add keybindings for these, but we do want to be able to use them
mp.add_key_binding(opt.addURL, "append_url_zenity", addURL)
mp.add_key_binding(opt.openURL, "open_url_zenity", openURL)
mp.add_key_binding(opt.openPlaylist, "open_playlist_zenity", openPlaylist)
mp.add_key_binding(opt.addAudio, "add_audio_zenity", addAudio)
