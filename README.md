# Context Menu for mpv

This is a Tcl/Tk context menu forked and fairly extensively modified from [this one](https://gist.github.com/avih/bee746200b5712220b8bd2f230e535de) (credit to avih). This is an example of what it looks like in use (showing the audio Channel Layout sub-menu):

<img src="http://i.imgur.com/8xmOqXW.png" width="768">

A lot of the code from the original menu has been rewritten. In particular, this menu adds sub-menu's using the Tcl menu cascade command. One possible downside to this is that the way in which the pseudo sub-menu worked with the original menu allowed a menu to stay on screen and be rebuilt, meaning that you could click a menu item to toggle something and have the menu stay on screen. This does not work with this menu.

The menu layout is based on by the right-click menu for Bomi, which is what I was using before switching to mpv. If you were a Bomi user be aware that not all the menu items for Bomi are implemented, particularly those around video settings and there is no current plan to implement them at this point.

Some of the menu items reference commands that use the functions/bindings in `zenity-dialogs.lua` to show dialogs. These are based on the [KDialog-open-files](https://gist.github.com/ntasos/d1d846abd7d25e4e83a78d22ee067a22) script (credit to ntasos).

## Requirements

This requires **tcl**, **tk** and **zenity** installed to work.

Place the `.lua` files in your `~/.config/mpv/scripts/` or `~/.mpv/scripts/` folder. The `input.conf` is not strictly necessary, but the key-bindings shown in the menu are based on those in the `input.conf` . **Note:** the key-bindings are not automatically detected and have been manually added as text to the menu, so you'll need to change/remove them if they don't match your own.

You will need to install Tcl and Tk and ensure that the interpreter variable in `mpvcontextmenu.lua` is set properly. This can be set to `wish` or `tclsh` (set to `wish` by default) and should either be accessible via the PATH environment variable or the full path should be specified.

Similarly, Zenity needs to be installed and accessible via the PATH or set it up manually in `zenity-dialogs.lua`. If you do not wish to use the zenity dialogs, remove the entries in the menu items referencing them.

The menu uses the Source Code Pro font, which can be [found here](https://github.com/adobe-fonts/source-code-pro) (or check your repositories), however the font can be changed in the `mpvcontextmenu.tcl` file. A mono-spaced font must be used for the menu items to appear correctly.

To get a list of fonts available to specify the correct name for Tcl/Tk, from a terminal run `wish` and from the wish prompt, enter `puts [font families]`.

    user@hostname:~$ wish
    % puts [font families]
This should output a list of fonts enclosed by curly braces, which can be used to copy the name of the desired font. To exit, type `exit`.

    % exit
Set the font to be used in `mpvcontextmenu.tcl`, changing the line with `{Source Code Pro}` below in the Tcl file to whichever font is preferred and adjusting size as desired.

```
font create defFont -family {Source Code Pro} -size 9
```

Additionally the context menu uses some other mpv scripts via script-binding/script-message. These are currently:

- [subit](https://github.com/wiiaboo/mpv-scripts/blob/master/subit.lua) for the "Find Subtitle (Subit)" item under "Tools"
- [playlistmanager](https://github.com/donmaiq/Mpv-Playlistmanager) for the "Show" item under "Tools > Playlist"
- [stats](https://github.com/Argon-/mpv-stats/) for the "Playback Information" item under "Tools"

These will need to be either downloaded and set-up for these menu items to work or the commands to use them should be removed if not.

## Usage

There is no default binding for the context menu and it needs to be specified via a binding in `input.conf` via `<BINDING> script_message mpv_context_menu` replacing the binding with the desired key-binding. To get this to work with the right-click button of the mouse, for instance, you would use:

    MOUSE_BTN2 script_message mpv_context_menu
The default bindings for the dialogs in `zenity-dialogs.lua` are:

|                                      Key | Action                                   |
| ---------------------------------------: | :--------------------------------------- |
|           <kbd>Ctrl</kbd> + <kbd>F</kbd> | Open files, replacing the playlist       |
|           <kbd>Ctrl</kbd> + <kbd>G</kbd> | Open a folder, replacing the playlist    |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> +<kbd>F</kbd> | Add/append files to the playlist         |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> +<kbd>G</kbd> | Add/append a folder to the playlist      |
|           <kbd>Shift</kbd> +<kbd>F</kbd> | Open a subtitle file (for the playing file) |

## Configuration

Both `zenity-dialogs.lua` and `mpvcontextmenu.lua` will read options stored in respective config files in a `lua-settings` directory in your mpv config directory (mentioned above). The files should be named the same as the Lua files but with `.conf` instead of `.lua` on the end. Check the near the top of each of the files to see which settings can be changed.

For instance, if you want to change the key-bindings for the dialogs, you could create `zenity-dialogs.conf` and specify the shortcuts as such:

    # Open files and open folder
    addFiles=Ctrl+f
    addFolder=Ctrl+g
Keep in mind that the shorcut style should match the `input.conf` format that mpv uses (allowing for case sensitivity) and that there should be no space between the `=` and the value after the `=` should not use quote marks.

For the context menu itself, the options listed in the top of the file specify the unit for the values used. It's important to specify the options in a conf file keeping the same unit values in mind (e.g. Audio Sync is set up for milliseconds but Seek is set up for seconds). An example for `mpvcontextmenu.conf` might be:

```
# Play > Seek - Seconds
seekSmall=10
seekMedium=60
seekLarge=600
# Audio > Volume - Percentage
audVol=1
```

Note that the changes to the values here only affect the menu, not the values for shortcuts in the `input.conf` which has to be edited separately.

## Customization

For those wishing to change the menu items or add/remove menu items, the following should help, though looking at the code directly will be best. It's best if you know some Lua to make changes here.

### Menu Layout

The menu layouts use what Lua calls tables, though you could also think of them as arrays (I certainly do).

When the pseudo-gui is in use and there is no file playing, the layout for the menus are sets of tables nested inside an over-arching table called menuList. This layout uses a select number of relevant options from the "while playing" menu allowing for a slightly different menu.

For files that are playing, the layout for the menus are also nested inside an over-arching table called menuList, however this is wrapped inside a function that is triggered by the "file-loaded" event in mpv (registered with `mp.register_event`). This is important as some of the values and track-list items are not available until the file has been loaded.

For both, menus, the layout is inside a table:

```lua
menuList = {
    -- Menu items go here
}
```

Each menu item is itself a table.

A separator is comprised of a single item and uses the variable SEP to indicate this like so:

```lua
{SEP},
```

A full menu item table is comprised of six (6) items. The layout looks something like this:

```
{Item Type, Label, Accelerator, Command, Item State, Item Disable},
```

Using the above as a guide, this table provides some information for what can/should be entered for each item.

| Value        | Purpose                                  |
| ------------ | ---------------------------------------- |
| Item Type    | The item type specifies whether this is a a cascade (sub-menu), command, checkbox, radio item, etc. |
| Label        | The label for the menu item and is what will be seen when using the menu. |
| Accelerator  | The shortcut for the menu item and will show to the right of the label when using the menu. |
| Command      | The command you want to be executed when an item is clicked on. |
| Item State   | For checkboxes and radio items, this is the selected/unselected state. |
| Item Disable | This is set to true or false depending on whether the menu item should be clickable/usable. |

For **Item Type**, this should be one of the preset variable names, CASCADE, COMMAND, CHECK and RADIO respectively.

The **Label** and **Accelerator** items become the actual text that shows for each menu item.

**Command** is either the a command to be sent directly to mpv (via `mp.command`) or a function call that will do something (better detailed further below).

The **Item State** should normally be `true` or `false` values, though there is a special case for the A/B Repeat where the receiving script will handle "a", "b" or "off" values and change the appearance of the "checkbox" based on the value.

The best way to handle this for checkboxes or radio items is to wrap a function that will return a true/false for the respective menu item in a function call (detailed below).

The **Item Disable** item is used to enable/disable menu items and can also disable cascades from functioning. This can be useful if a menu item should be disabled when certain functionality is not available with a given file. Set this to `true` to disable the item and `false` to leave it enabled.

For the **Item Label**, **Accelerator** and **Command** items, you can use string concatenation `("Text " .. var .. " Text")` as the value is evaluated at much the same time as in-line functions returning values (detailed below).

All six items should be entered and empty quotes used when not specifying a value.

An example item with these in mind, could be like so:

```lua
{Command, "Toggle Fullscreen", "F", "cycle fullscreen", "", false},
```

With all that in mind, a basic menu might look something like this (it's important to remember your commas!):

```lua
menuList = {
    context_menu = {
        {CASCADE, "Play", "play_menu", "", "", false},
    },
  
    play_menu = {
        {COMMAND, "Play/Pause", "Space", "cycle pause", "", false},
        {COMMAND, "Stop", "Ctrl+Space", "stop", "", false},
        {SEP},
        {COMMAND, "Previous", "<", "playlist-prev", "", false},
        {COMMAND, "Next", ">", "playlist-next", "", false},
    },
}
```

The **CASCADE** item is special in that the third value in the table for a cascade menu item is the name of the table that should cascade from that menu item.

In the above example, the cascade will have the `play_menu` table as a sub-menu coming off of it. There is a maximum of 6 total menu levels, including the base, making for up to 5 sub-menu levels deep. Any more than that will throw an error, which also prevents infinite recursion in the menu building function.

### Function call/in-line function

Apart from the separator, the menu items can make use of a function call:

```lua
function() return somefunction() end
```

Apart from the **Command** item, this function call is evaluated each time the menu is built (each time the script-message shortcut binding is activated). This allows you to dynamically build labels or set values at the time of creating the menu.

In the instance of the **Command** item, if there is a function call, this will be evaluated as a function only upon being clicked and will **not** send a command unless you do so within your function. If there is not a function call, the command provided will be sent to mpv.

There is also a difference between a function call like the above and an in-line function returning a value as part of building a command to send to mpv. For instance, if we had a menu item like this:

```lua
{Command, getLabel(), "Shift+L", "", "", getState()}
```

When the Lua code is being executed (either on initially being loaded or after a file is loaded), the getLabel() and getState() functions would be run and should return a label string and a true/false value respectively.

## Notes

One of the files included is the `langcodes.lua` which holds two tables filled with associative arrays using the 2 or 3 character long language name representations (ISO 639-1 and ISO 639-2) as property accessors to get full length language names, though these are only in English at this point.

## Disclaimer

I have tried to test this on a variety of media files and have attempted to deal with any bugs that have arisen, but I can't guarantee that this is bug-free. There may be use-cases I haven't considered or some functions may throw errors from unexpected values/input.

## Credits

Thanks go out to the following people:

* avih for the [original Tcl/Tk context menu](https://gist.github.com/avih/bee746200b5712220b8bd2f230e535de) upon which this menu has been built
* ntasos for some code and ideas from the [KDialog-open-files](https://gist.github.com/ntasos/d1d846abd7d25e4e83a78d22ee067a22) script