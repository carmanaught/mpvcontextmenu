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
# 2017-07-27 - Version 0.4 - Make the menuchange parsing more dynamic to match with the
#                            changes in mpvcontextmenu.lua
#
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
set errorVal "errorVal"
array set maxAccel {}
array set mVal {}

# To make the accelerator appear as if they're justified to the right, we iterate through
# the entire list and set the maximum accelerator length for each menu ($mVal(1)) after
# check if a value exists first, increasing the max value if the length of an item is greater.
foreach {mVal(1) mVal(2) mVal(3) mVal(4) mVal(5) mVal(6) mVal(7)} $argList {
    if {$mVal(1) != "changemenu" || $mVal(1) != "cascade"} {
        if {![info exists ::maxAccel($mVal(1))]} {
            set ::maxAccel($mVal(1)) [string length $mVal(5)]
        } else {
        if {[string length $mVal(5)] > $::maxAccel($mVal(1))} {
            set ::maxAccel($mVal(1)) [string length $mVal(5)]
        }
        }
    }
}

# We call this when creating the accelerator labels, passing the current menu ($mVal(1))
# and the accelerator, getting the max length for that menu and adding 4 spaces, then
# appending the label after the spaces, making it appear justified to the right.
proc makeLabel {curTable accelLabel} {
    set spacesCount [expr [expr $::maxAccel($curTable) + 4] - [string length $accelLabel]]
    set whiteSpace [string repeat " " $spacesCount]
    set fullLabel $whiteSpace$accelLabel
    return $fullLabel
}

# The assumed values for most iterations are:
# mVal(1) = Table Name
# mVal(2) = Table Index
# mVal(3) = Item Type
# mVal(4) = Item Label
# mVal(5) = Item Accelerator/Shortcut
# mVal(6) = Item State (Check/Unchecked, etc)
# mVal(7) = Item Disable (True False)
foreach {mVal(1) mVal(2) mVal(3) mVal(4) mVal(5) mVal(6) mVal(7)} $argList {
    if {$first} {
        set pos_x $mVal(1)
        set pos_y $mVal(2)
        set baseMenuName $mVal(3)
        set baseMenu [menu .$baseMenuName -tearoff 0]
        set curMenu .$mVal(3)
        set preMenu .$mVal(3)
        set first 0
        continue
    }
    
    if {$mVal(1) != "changemenu"} {
        if {$mVal(7) == "false"} {
            set mVal(7) "normal"
        } elseif {$mVal(7) == "true"} {
            set mVal(7) "disabled"
        } else {
            set mVal(7) "normal"
        }
    }
    
    if {$mVal(1) == "changemenu"} {
        set changeCount 0
        set menuLength 0
        set mCheck ""
        set arrSize [array size mVal]
        # Check how many empty values are in the list and increase the $changeCount variable to
        # subtract that value from the size of the array of values (currently 7), giving the
        # total number of values that have actually been passed, which is how many times we'll
        # increment through to set our menu values.
        for {set i 2} {$i <= $arrSize} {incr i} {
            if {$mVal($i) == ""} { set changeCount [expr $changeCount + 1] }
        }
        set menuLength [expr $arrSize - $changeCount]
        # We're going to assume that the right-most value that isn't "" of the foreach variables
        # when doing a menu change is the highest level of menu and that there's been no gaps of
        # "" values (which there shouldn't be).
        for {set i 2} {$i <= $menuLength} {incr i} {
            if {$i == 2} {
                set mCheck .$mVal($i)
                set preMenu $mCheck
                set curMenu $mCheck
            } else {
                set preMenu $mCheck
                set mCheck $mCheck.$mVal($i)
                set curMenu $mCheck
            }
            if {![winfo exists $mCheck]} {
                menu $mCheck -tearoff 0
            }
        }
        continue
    }

    if {$mVal(1) == "cascade"} {
        # Reverse the $curMenu and $preMenu here so that the menu so that it attaches in the
        # correct order.
        $preMenu add cascade -label $emptyPre$mVal(2) -state $mVal(7) -menu $curMenu
        continue
    }
    
    if {$mVal(3) == "separator"} {
        $curMenu add separator
        continue
    }
    
    if {$mVal(3) == "command"} {
        $curMenu add command -label $emptyPre$mVal(4) -accel [makeLabel $mVal(1) $mVal(5)] -state $mVal(7) -command "done $mVal(1) $mVal(2) $errorVal"
        continue
    }
    
    # For checkbutton/radiobutton I'll just add command items for now, until I can get the
    # theming to work right and show the buttons based on a specified theme.
    
    if {$mVal(3) == "checkbutton"} {
        if {$mVal(6) == "true"} {
            set labelPre $boxCheck
        } else {
            set labelPre $boxUncheck
        }
        
        $curMenu add command -label $labelPre$mVal(4) -accel [makeLabel $mVal(1) $mVal(5)] -state $mVal(7) -command "done $mVal(1) $mVal(2) $errorVal"
        continue
    }
    
    if {$mVal(3) == "radiobutton"} {
        if {$mVal(6) == "true"} {
            set labelPre $radioSelect
        } else {
            set labelPre $radioEmpty
        }
        
        $curMenu add command -label $labelPre$mVal(4) -accel [makeLabel $mVal(1) $mVal(5)] -state $mVal(7) -command "done $mVal(1) $mVal(2) $errorVal"
        continue
    }
    
    if {$mVal(3) == "ab-button"} {
        if {$mVal(6) == "a"} {
            set labelPre $boxA
        } elseif {$mVal(6) == "b"} {
            set labelPre $boxB
        } elseif {$mVal(6) == "off"} {
            set labelPre $boxUncheck
        }
        
        $curMenu add command -label $labelPre$mVal(4) -accel [makeLabel $mVal(1) $mVal(5)] -state $mVal(7) -command "done $mVal(1) $mVal(2) $errorVal"
        continue
    }
}

# Read the absolute mouse pointer position if we're not given a pos via argv
if {$pos_x == -1 && $pos_y == -1} {
    set pos_x [winfo pointerx .]
    set pos_y [winfo pointery .]
}

proc done {menuName index errorValue} {
    puts -nonewline "{\"menuname\":\"$menuName\", \"index\":\"$index\", \"errorvalue\":\"$errorValue\"}"
    exit
}

# Seemingly, on both windows and linux, "cancelled" is reached after the click but
# before the menu command is executed and _a_sync to it. Therefore we wait a bit to
# allow the menu command to execute first (and exit), and if it didn't, we exit here.
proc cancelled {} {
    after 100 {done $baseMenuName $::RESP_CANCEL $::errorVal}
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
