--[[ *************************************************************
 * Context menu engine for mpv.
 * Originally by Avi Halachmi (:avih) https://github.com/avih
 * Extended by Thomas Carmichael (carmanught) https://github.com/carmanaught
 *
 * Features:
 * - Comprehensive sub-menus providing access to various mpv functionality
 * - Dynamic menu items and commands, disabled items, separators.
 * - Reasonably well behaved/integrated considering it's an external application.
 * - Configurable options for some values (changes visually in menu too)
 *
 * Requirements:
 * - Check https://github.com/carmanaught/mpvcontextmenu for further setup instructions
 *
 * 2017-02-02 - Version 0.1 - Initial version (avih)
 * 2017-07-19 - Version 0.2 - Extensive rewrite (carmanught)
 * 2017-07-20 - Version 0.3 - Add/remove/update menus and include zenity bindings (carmanught)
 * 2017-07-22 - Version 0.4 - Reordered context_menu items, changed table length check, modify
 *                            menu build iterator slightly and add options (carmanaught)
 * 2017-07-27 - Version 0.5 - Added function (with recursion) to build menus (allows dynamic
 *                            menus of up to 6 levels (top level + 5 sub-menu levels)) and
 *                            add basic menu that will work when nothing is playing.
 * 2017-08-01 - Version 0.6 - Add back the menu rebuild functionality.
 * 2017-08-04 - Version 0.7 - Separation of menu building from definitions.
 * 2017-08-07 - Version 0.8 - Updated to better support an additional menu builder
 *
 ***************************************************************
--]]

local utils = require 'mp.utils'
local verbose = false  -- true -> Dump console messages also without -v
local function info(x) mp.msg[verbose and "info" or "verbose"](x) end
local function mpdebug(x) mp.msg.info(x) end -- For printing other debug without verbose

-- Use tables to specify the interpreter and menuscript to allow for multiple menu
-- builders along with the associated logic changes to handle them.
local interpreter = {}
local menuscript = {}

interpreter["tk"] = "wish";  -- tclsh/wish/full-path
menuscript["tk"] = mp.find_config_file("scripts/menu-builder-tk.tcl")

-- The js file is provided without an extension so that mpv doesn't try to load it
-- (allowing for mpv with MuJS support).
interpreter["gtk"] = "gjs";  -- lua/full-path
menuscript["gtk"] = mp.find_config_file("scripts/menu-builder-gtk-js")


-- Set some constant values. These should match what's used with the menu definitions.
local SEP = "separator"
local CASCADE = "cascade"
local COMMAND = "command"
local CHECK = "checkbutton"
local RADIO = "radiobutton"
local AB = "ab-button"

-- In addition to what's passed by the menu definition list, also send these (prefixed 
-- before the other items). We'll add these programattically, so no need to add these
--  items to the tables.
--
-- Current Menu - context_menu, play_menu, etc.
-- Menu Index - This is the table index of the Current Menu, so we can use the Index in
-- concert with the menuList to get the command, e.g. menuList["play_menu"][1][4] for
-- the command stored under the first menu item in the Play menu.

local menuBuilder = ""

local function doMenu(menuList, menuName, x, y, menuPaths, menuIndexes)
    local mousepos = {}
    mousepos.x, mousepos.y = mp.get_mouse_pos()
    if (x == -1) then x = tostring(mousepos.x) end
    if (y == -1) then y = tostring(mousepos.y) end
    menuPaths = (menuPaths ~= nil) and tostring(menuPaths) or ""
    menuIndexes = (menuIndexes ~= nil) and tostring(menuIndexes) or ""
    -- For the first run, we'll send the name of the base menu after the x/y
    -- and any menu paths and menu indexes if there are any (used to re'post'
    -- a menu).
    local args = {x, y, menuName, menuPaths, menuIndexes, "", ""}
    
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
                if not (i == 4) then
                    if not (i == 7) then args[#args+1] = argType(argList[i]) end
                end
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
    local function addCascade(label, state, index)
        args[#args+1] = CASCADE
        args[#args+1] = (argType(label) ~= emptyStr) and argType(label) or ""
        args[#args+1] = index
        for iter = 1, 3 do
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
            curMenu[mLvl] = menuList[mName]
            
            for i = 1, #curMenu[mLvl] do
                if (curMenu[mLvl][i][1] == CASCADE) then
                    -- Set sub menu names and objects
                    menuNames[mLvl+1] = curMenu[mLvl][i][3]
                    curMenu[mLvl+1] = menuList[menuNames[mLvl+1]]
                    -- Change menu to the sub-menu
                    menuChange(menuNames)
                    -- Recurse in and build again
                    buildMenu(menuNames[mLvl+1], (mLvl + 1))
                    -- Add the cascade
                    addCascade(curMenu[mLvl][i][2], curMenu[mLvl][i][6], i)
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
            -- "menuchange" value, 1 for the base menu, leaving 5 more, for 6 total. This
            -- also stops infinitely recursive cascades.
            mp.osd_message("Too many menu levels. No more than 6 menu levels total.")
            stopCreate = true
            do return end
        end
    end
    
    -- Build the menu using the menu name provided to the function
    buildMenu(menuName, 1)
    
    -- Stop building the menu if there was an issue with too many menu levels since it'll just
    -- cause problems
    if (stopCreate == true) then do return end end
    
    local argList = args[1]
    for i = 2, #args do
        argList = argList .. "|" .. args[i]
    end
    
    -- We use the chosen menu builder with the interpreter and menuscript tables as the key
    -- to define which script we're going to call. The builder should be written to handle
    -- the information passed to it and provide output back to us in the format we want.
    local cmdArgs = {interpreter[menuBuilder], menuscript[menuBuilder], argList}
    
    -- retVal gets the return value from the subprocess
    local retVal = utils.subprocess({
        args = cmdArgs,
        cancellable = true
    })
    
    -- Show an error and stop executing if the subprocess has an error
    if (retVal.status ~= 0) then
        mp.osd_message("Possible error in mpvcontextmenu.tcl")
        return
    end
    
    info("ret: " .. retVal.stdout)
    -- Parse the return value as JSON and assign the JSON values.
    local response = utils.parse_json(retVal.stdout, true)
    response.x = tonumber(response.x)
    response.y = tonumber(response.y)
    response.menuname = tostring(response.menuname)
    response.index = tonumber(response.index)
    response.menupath = tostring(response.menupath)
    if (response.index == -1) then
        info("Context menu cancelled")
        return
    end
    
    local respMenu = menuList[response.menuname]
    local menuIndex = response.index
    local menuItem = respMenu[menuIndex]
    if (not (menuItem and menuItem[4])) then
        mp.msg.error("Unknown menu item index: " .. tostring(response.index))
        return
    end
    
    -- Run the command accessed by the menu name and menu item index return values
    if (type(menuItem[4]) == "string") then
        mp.command(menuItem[4])
    else
        menuItem[4]()
    end
    
    -- Currently only the 'tk' menu supports a rebuild or re'post' to show the menu re-cascaded to
    -- the same menu it was on when it was clicked.
    if (menuBuilder == "tk") then
        -- Re'post' the menu if there's a seventh menu item and it's true. Only available for tk menu
        -- at the moment.
        if (menuItem[7]) then
            if (menuItem[7] ~= "boolean") then
                rebuildMenu = (menuItem[7] == true) and true or false
            end
            
            if (rebuildMenu == true) then
                -- Figure out the menu indexes based on the path and send as args to re'post' the menu
                menuPaths = ""
                menuIndexes = ""
                local pathList = {}
                local idx = 1
                for path in string.gmatch(response.menupath, "[^%.]+") do
                    pathList[idx] = path
                    idx = idx + 1
                end
                
                -- Iterate through the menus and build the index values
                for i = 1, (#pathList - 1) do
                    for pathInd = 1, i do
                        menuPaths = menuPaths .. "." .. pathList[pathInd]
                    end
                    if not (i == (#pathList - 1)) then
                        menuPaths = menuPaths .. "?"
                    end
                    menuFind = menuList[pathList[i]]
                    for subi = 1, (#menuFind) do
                        if (menuFind[subi][1] == CASCADE) then
                            if (menuFind[subi][3] == pathList[i+1]) then
                                -- The indexes for using the postcascade in Tcl are 0-based
                                menuIndexes = menuIndexes .. (subi - 1)
                                if not (i == (#pathList - 1)) then
                                    menuIndexes = menuIndexes .. "?"
                                end
                            end
                        end
                    end
                end
                
                -- Break direct recursion with async, stack overflow can come quick.
                -- Also allow to un-congest the events queue.
                mp.add_timeout(0, function() doMenu(menuList, "context_menu", x, y, menuPaths, menuIndexes) end)
            else
                mpdebug("There's a problem with the menu rebuild value")
            end
        end
    end
end

local function createMenu(menu_list, menu_name, x, y, menu_builder)
    menuBuilder = menu_builder
    doMenu(menu_list, menu_name, x, y)
end

local menuBuilder = {
    createMenu = createMenu
}

return menuBuilder