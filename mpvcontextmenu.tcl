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
# 2017-07-22 - Version 0.3 - Change accelerator label handling (right align) and adjust
#                            changemenu check to match mpvcontextmenu.lua changes
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
    puts "Usage: context.tcl x y \"base menu name\" (4 x \"\") .. \"sets of 7 args\""
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
set radioSelect "(X) "
set radioEmpty "( ) "
set boxA "\[A\] "
set boxB "\[B\] "
set emptyPre "    "
set accelSpacer "   "
set labelPre ""
set menuWidth 36
set baseMenuName "context_menu"
set first 1
array set maxAccel {}

# To make the accelerator appear as if they're justified to the right, we iterate through
# the entire list and set the maximum accelerator length for each menu ($tableName) after
# check if a value exists first, increasing the max value if the length of an item is greater.
foreach {tableName tableIndex itemType itemLabel itemAccel itemState itemDisable} $argList {
    if {$tableName != "changemenu" || $tableName != "cascade"} {
        if {![info exists ::maxAccel($tableName)]} {
            set ::maxAccel($tableName) [string length $itemAccel]
        } else {
        if {[string length $itemAccel] > $::maxAccel($tableName)} {
            set ::maxAccel($tableName) [string length $itemAccel]
        }
        }
    }
}

# We call this when creating the accelerator labels, passing the current menu ($tableName)
# and the accelerator, getting the max length for that menu and adding 4 spaces, then
# appending the label after the spaces, making it appear justified to the right.
proc makeLabel {curTable accelLabel} {
    set spacesCount [expr [expr $::maxAccel($curTable) + 4] - [string length $accelLabel]]
    set whiteSpace [string repeat " " $spacesCount]
    set fullLabel $whiteSpace$accelLabel
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
    
    if {$tableName == "changemenu"} {
        if {$itemType == ""} {
            if {![winfo exists .$tableIndex]} {
                menu .$tableIndex -tearoff 0
            }
            set curMenu .$tableIndex
            set preMenu .$tableIndex
        } else {
            if {$itemLabel == ""} {
                if {![winfo exists .$tableIndex]} { 
                    menu .$tableIndex -tearoff 0
                }
                if {![winfo exists .$tableIndex.$itemType]} {
                    menu .$tableIndex.$itemType -tearoff 0
                }
                set curMenu .$tableIndex.$itemType
                set preMenu .$tableIndex
            } else {
                if {![winfo exists .$tableIndex]} {
                    menu .$tableIndex -tearoff 0
                }
                if {![winfo exists .$tableIndex.$itemType]} {
                    menu .$tableIndex.$itemType -tearoff 0
                }
                if {![winfo exists .$tableIndex.$itemType.$itemLabel]} {
                    menu .$tableIndex.$itemType.$itemLabel -tearoff 0
                }
                set curMenu .$tableIndex.$itemType.$itemLabel
                set preMenu .$tableIndex.$itemType
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
        $curMenu add command -label $emptyPre$itemLabel -accel [makeLabel $tableName $itemAccel] -state $itemDisable -command "done $tableName $tableIndex"
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
        
        $curMenu add command -label $labelPre$itemLabel -accel [makeLabel $tableName $itemAccel] -state $itemDisable -command "done $tableName $tableIndex"
        continue
    }
    
    if {$itemType == "radiobutton"} {
        if {$itemState == "true"} {
            set labelPre $radioSelect
        } else {
            set labelPre $radioEmpty
        }
        
        $curMenu add command -label $labelPre$itemLabel -accel [makeLabel $tableName $itemAccel] -state $itemDisable -command "done $tableName $tableIndex"
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
        
        $curMenu add command -label $labelPre$itemLabel -accel [makeLabel $tableName $itemAccel] -state $itemDisable -command "done $tableName $tableIndex"
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
