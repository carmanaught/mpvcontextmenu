# Context Menu for mpv

This is a Tcl/Tk context menu forked and heavily modified from [this one](https://github.com/carmanaught/mpvcontextmenu) (credit to avih). One of the key differences between this and the fork is that this generates sub-menu's. There are a number of comments in the Lua and Tcl files that hopefully provide some explanation of what's going on or how to structure the list of items, but looking over the list will give some indication.

The basis for the menu layout is based on the menu for Bomi, which is what I was using before switching to use mpv. There is some **work-in-progress** and there may be bugs. A few menu items are outright disabled where I haven't created a sub-menu or haven't implemented functionality for the items to work. Some items may also be disabled based on if there are certain tracks or items (e.g. video / chapter / title / edition / etc.).

One of the Lua files included is the langcodes.lua which holds two tables filled with associative arrays using the 2 or 3 character long language name representations (ISO 639-1 and ISO 639-2) as property accessors to get full length language names, though these are only in English at this point.

The zenity-dialogs.lua holds the code and keybindings for dialogs using zenity based on the [KDialog-open-files](https://gist.github.com/ntasos/d1d846abd7d25e4e83a78d22ee067a22) script (credit to ntasos).

Much of the menu is currently set up to reflect my mpv settings, which can be seen from my [dotfiles](https://github.com/carmanaught/dotfiles).

The keybinding values are what I use and have been added manually, not read from the input.conf. I may consider this but at this point, any changes to shortcuts need to be updated in the lua file directly.

The seek time amounts are currently hardcoded, but I may look at making those customisable and having the menu labels reflect the change. This wouldn't affect shortcuts in the input.conf however.

The context menu uses some of the mpv scripts I've downloaded and use myself. I may add more if someone else has functionality that I need not implement myself, but the other scripts I reference in the menu are:

* [subit](https://github.com/wiiaboo/mpv-scripts/blob/master/subit.lua)
* [playlistmanager](https://github.com/donmaiq/Mpv-Playlistmanager)
* [stats](https://github.com/Argon-/mpv-stats/)
