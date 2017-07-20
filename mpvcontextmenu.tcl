# #############################################################
# Context menu constructed via CLI args.
# Originally by Avi Halachmi (:avih) https://github.com/avih
# Extended by Thomas Carmichael (carmanught) https://github.com/carmanaught
#
# Developed for and used in conjunction with mpvcontextmenu.lua - context-menu for mpv.
# See mpvcontextmenu.lua for more info.
#
# 2017-02-02 - Version 0.1 - Initial version (avih)
# 2017-07-19 - Version 0.2 - Extensive rewrite (carmanught)
# #############################################################

# Required when launching via tclsh, no-op when launching via wish
package require Tk
font create defFont -family {Source Code Pro} -size 9
option add *font defFont
# This doesn't appear to do anything for the styling. Wrong command?
ttk::style theme use clam

# Remove the main window from the host window manager
wm withdraw .

set argList [split [lindex $argv 0] "|"]

if { $::argc < 1 } {
    puts "Usage: context.tcl menufile"
    exit 1
}

# Construct the menu from argv:
# - The first set of values contains the absolute x, y menu position, or
# - under the mouse if -1, -1, as well as the base menu name.
# - The rest of the pairs are display-string, return-value-on-click.
#   If the return value is empty then the display item is disabled, but if the
#   display is "-" (and empty rv) then a separator is added instead of an item.
# - For now, return-value is expected to be a number, and -1 is reserved for cancel.
#
# On item-click/menu-dismissed, we print a json object to stdout with the
# menu name and and index.
set RESP_CANCEL -1

set boxCheck "\[X\] "
set boxUncheck "\[ \] "
set radioSelect "(x) "
set radioEmpty "( ) "
set boxA "\[A\] "
set boxB "\[B\] "
set emptyPre "    "
set accelSpacer "   "
set labelPre ""
set menuWidth 36
set baseMenuName "context_menu"
set first 1

# I haven't found a way to right-justify the accelerator so we'll just build the label
# and shortcut together and add spaces between instead of using:
# -accel $accelSpacer$itemAccel
proc makeLabel {pre lbl acl} {
    set spacesCount [expr $::menuWidth - [string length $pre] - [string length $lbl] - [string length $acl]]
    set whiteSpace [string repeat " " $spacesCount]
    set fullLabel $pre$lbl$whiteSpace$acl
    return $fullLabel
}

foreach {tableName tableIndex itemType itemLabel itemAccel itemState itemDisable} $argList {
    if {$first} {
        set pos_x $tableName
        set pos_y $tableIndex
        set baseMenuName $itemType
        set baseMenu [menu .$baseMenuName -tearoff 0]
        set curMenu .$itemType
        set preMenu .$itemType
        set first 0
        continue
    }
    
    if {$itemDisable == "false"} {
        set itemDisable "normal"
    } elseif {$itemDisable == "true"} {
        set itemDisable "disabled"
    } else {
        set itemDisable "normal"
    }
    
    if {$itemType == "changemenu"} {
        if {$itemAccel == ""} {
            # Need to understand how menus work to fix window name $menuname already exists
            if {![winfo exists .$itemLabel]} {
                menu .$itemLabel -tearoff 0
            }
            set curMenu .$itemLabel
            set preMenu .$itemLabel
        } else {
            if {$itemState == ""} {
                if {![winfo exists .$itemLabel]} { 
                    menu .$itemLabel -tearoff 0
                }
                if {![winfo exists .$itemLabel.$itemAccel]} {
                    menu .$itemLabel.$itemAccel -tearoff 0
                }
                set curMenu .$itemLabel.$itemAccel
                set preMenu .$itemLabel
            } else {
                if {![winfo exists .$itemLabel]} {
                    menu .$itemLabel -tearoff 0
                }
                if {![winfo exists .$itemLabel.$itemAccel]} {
                    menu .$itemLabel.$itemAccel -tearoff 0
                }
                if {![winfo exists .$itemLabel.$itemAccel.$itemState]} {
                    menu .$itemLabel.$itemAccel.$itemState -tearoff 0
                }
                set curMenu .$itemLabel.$itemAccel.$itemState
                set preMenu .$itemLabel.$itemAccel
            }
        }
        continue
    }

    if {$tableName == "cascade"} {
        # Reverse the $curMenu and $preMenu here so that the menu so that it attaches in the
        # correct order.
        $preMenu add cascade -label $emptyPre$tableIndex -state $itemDisable -menu $curMenu
        continue
    }
    
    if {$itemType == "separator"} {
        $curMenu add separator
        continue
    }
    
    if {$itemType == "command"} {
        $curMenu add command -label [makeLabel $emptyPre $itemLabel $itemAccel] -state $itemDisable -command "done $tableName $tableIndex"
        continue
    }
    
    # For checkbutton/radiobutton I'll just add command items for now, until I can get the
    # theming to work right and show the buttons based on a specified theme.
    
    if {$itemType == "checkbutton"} {
        if {$itemState == "true"} {
            set labelPre $boxCheck
        } else {
            set labelPre $boxUncheck
        }
        
        $curMenu add command -label [makeLabel $labelPre $itemLabel $itemAccel] -state $itemDisable -command "done $tableName $tableIndex"
        continue
    }
    
    if {$itemType == "radiobutton"} {
        if {$itemState == "true"} {
            set labelPre $radioSelect
        } else {
            set labelPre $radioEmpty
        }
        
        $curMenu add command -label [makeLabel $labelPre $itemLabel $itemAccel] -state $itemDisable -command "done $tableName $tableIndex"
        continue
    }
    
    if {$itemType == "ab-button"} {
        if {$itemState == "a"} {
            set labelPre $boxA
        } elseif {$itemState == "b"} {
            set labelPre $boxB
        } elseif {$itemState == "off"} {
            set labelPre $boxUncheck
        }
        
        $curMenu add command -label [makeLabel $labelPre $itemLabel $itemAccel] -state $itemDisable -command "done $tableName $tableIndex"
        continue
    }
    
}

# Read the absolute mouse pointer position if we're not given a pos via argv
if {$pos_x == -1 && $pos_y == -1} {
    set pos_x [winfo pointerx .]
    set pos_y [winfo pointery .]
}

proc done {menuName index} {
    puts -nonewline "{\"menuname\":\"$menuName\", \"index\":\"$index\"}"
    exit
}

# Seemingly, on both windows and linux, "cancelled" is reached after the click but
# before the menu command is executed and _a_sync to it. Therefore we wait a bit to
# allow the menu command to execute first (and exit), and if it didn't, we exit here.
proc cancelled {} {
    after 100 {done $baseMenuName $::RESP_CANCEL}
}

# Calculate the menu position relative to the Tk window
set win_x [expr {$pos_x - [winfo rootx .]}]
set win_y [expr {$pos_y - [winfo rooty .]}]

# Launch the popup menu
tk_popup $baseMenu $win_x $win_y

# On Windows tk_popup is synchronous and so we exit when it closes, but on Linux
# it's async and so we need to bind to the <Unmap> event (<Destroyed> or
# <FocusOut> don't work as expected, e.g. when clicking elsewhere even if the
# popup disappears. <Leave> works but it's an unexpected behavior for a menu).
# Note: if we don't catch the right event, we'd have a zombie process since no
#       window. Equally important - the script will not exit.
# Note: untested on macOS (macports' tk requires xorg. meh).
if {$tcl_platform(platform) == "windows"} {
    cancelled
} else {
    bind $baseMenu <Unmap> cancelled
}
