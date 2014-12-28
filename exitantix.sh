#!/bin/bash 
# File Name: exitantiX.sh
# Purpose: exit script from fluxbox and icewm
# Authors: OU812 and minor modifications by anticapitalista
# Latest Change: 20 August 2008
# Latest Change: 02 January 2009
# Latest Change: 24 October 2011 Localisation/internationalisation added by anticapitalista/BitJam 
# Latest Change: 23 September 2012 ICON function
######################################################################################################

TEXTDOMAINDIR=/usr/share/locale 
TEXTDOMAIN=exitantix.sh
ICONS=/usr/share/icons/antiX-1

export LOGOUT=$(cat <<End_of_Text

<window title="`gettext $"Log Out"`" window-position="1">

<vbox>
  <frame>
  <hbox>
	<vbox>
	  <hbox>
		<button>
		<input file>"$ICONS/lock.svg"</input>
        <action>EXIT:lock_antix</action>
		</button>
		<text use-markup="true" width-chars="15"><label>"`gettext $"Lock Screen"`"</label></text>
      </hbox>
	  <hbox>
		<button>
		<input file>"$ICONS/hibernate.svg"</input>
        <action>EXIT:hibernate_antix</action>
		</button>
		<text use-markup="true" width-chars="15"><label>"`gettext $"Hibernate"`"</label></text>
	  </hbox>
	  <hbox>
		<button>
		<input file>"$ICONS/reboot.svg"</input>
        <action>EXIT:reboot_antix</action>
		</button>
		<text use-markup="true" width-chars="15"><label>"`gettext $"Reboot"`"</label></text>
	  </hbox>
	</vbox>

	<vbox>
	  <hbox>
		<button>
		<input file>"$ICONS/logout.svg"</input>
        <action>EXIT:logout_antix</action>
		</button>
		<text use-markup="true" width-chars="15"><label>"`gettext $"Log Out"`"</label></text>
      </hbox>
	  <hbox>
		<button>
		<input file>"$ICONS/suspend.svg"</input>
        <action>EXIT:suspend_antix</action>
		</button>
		<text use-markup="true" width-chars="15"><label>"`gettext $"Suspend"`"</label></text>
	  </hbox>
	  <hbox>
		<button>
		<input file>"$ICONS/shutdown.svg"</input>
        <action>EXIT:shutdown_antix</action>
		</button>
		<text use-markup="true" width-chars="15"><label>"`gettext $"Shutdown"`"</label></text>
	  </hbox>
	</vbox>
  </hbox>
  </frame>
</vbox>
  
</window>
End_of_Text
)

I=$IFS; IFS=""
for STATEMENTS in  $(gtkdialog --program LOGOUT); do
  eval $STATEMENTS
done
IFS=$I

read_id_file() {
    FILE_ID=
    local file=$1:${DISPLAY%.[0-9]}
    local pid=$(cat $file 2>/dev/null)
    test -r $file; local ret=$?
    rm -f $file
    if [ $ret != 0 ]; then
        echo "Could not find/read file: $file"
        return 1
    fi

    if [ -z "$pid" ]; then
        echo "Empty file: $file"
        return 1
    fi
    FILE_ID=$pid
    return 0
}

kill_list() {
    local cmd pid list=$1
    local gdad=$(grep  ^PPid: /proc/$PPID/status | cut -f2)
    for pid in $list; do
        cmd=$(cat /proc/$pid/comm 2>/dev/null)
        case $pid in
            $$|$PPID|$gdad) continue ;;
        esac
        [ "$cmd" ] && echo "kill $cmd"
        kill $pid 2>/dev/null
    done
}

list_group() {
    local pgid=$1  save=$2
    [ "$pgid" ] || return
    for pid in $(pgrep -g $pgid); do
        [ "$pid" = "$save" ] && continue
        echo -n "$pid "
    done
}

clean_logout() {
    sdir=$HOME/.antix-session
    
    read_id_file $sdir/xinitrc-pid || return 1
    local wm_pid=$FILE_ID

    local wm_prog=$(cat /proc/$wm_pid/comm 2>/dev/null)
    local wm_pgid=$(cut -d" " -f5 /proc/$wm_pid/stat)

    echo -e "\n----------------------------------------------------------------"
    echo "${0##*/} ($$): clean logout from session: $wm_prog"

    read_id_file $sdir/startup-pgid
    local st_pgid=$FILE_ID

    local list=$(list_group "$st_pgid" "$wm_pid")
    if [ -n "$list" -a "$st_pgid" != "$wm_pgid" ]; then
        echo "Kill possible startup orphans ($st_pgid): $list"
        kill_list "$list"
    fi

    ps x -o pid,ppid,pgid,user,cmd

    list=$(list_group "$wm_pgid" "$wm_pid")
    if [ "$list" ]; then
        echo "Kill possible xinitrc orphans ($wm_pgid): $list"
        kill_list "$list"
    fi

    list=$(echo $(pgrep -P $wm_pid | tac) $wm_pid)
    if [ "$list" ]; then
        echo "Kill remaining processes: $list"
        kill_list "$list"
    fi

    list=$(echo $(pgrep -P $wm_pid | tac) $wm_pid)
    [ -d /proc/$wm_pid/ ] || return 0
    sleep 1
    [ -d /proc/$wm_pid/ ] || return 0
    echo "Finally kill $wm_prog"
    kill -9 $wm_pid
    return 0
}

if [ "$EXIT" = "lock_antix" ] ; then
	xlock
fi

if [ "$EXIT" = "logout_antix" ] ; then

    if clean_logout >&2; then
        echo "${0##*/}: exit"
        echo -e "----------------------------------------------------------------\n"
        exit

    elif [ $USER != root -a $UID != 0 ]; then
        echo "As a last resort, kill all \"$USER\" user processes" >&2
        pkill -U $USER
    fi
fi

if [ "$EXIT" = "reboot_antix" ] ; then
	if which persist-config &> /dev/null; then
		sudo persist-config --shutdown --command reboot
	else
		sudo reboot
	fi
fi

if [ "$EXIT" = "hibernate_antix" ] ; then
	dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Hibernate
fi

if [ "$EXIT" = "suspend_antix" ] ; then
	dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Suspend
fi

if [ "$EXIT" = "shutdown_antix" ] ; then
	if which persist-config &> /dev/null; then
		sudo persist-config --shutdown --command halt
	else
		sudo halt
	fi
fi
