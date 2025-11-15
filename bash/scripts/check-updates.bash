#!/bin/bash

# Count available updates
updates_count=0
updates_availables="$(checkupdates && yay -Qua)"

if [[ -n "$updates_availables" ]]; then
    updates_count=$(echo "$updates_availables" | wc -l )
fi

echo "updates count: $updates_count"

# check if a linux update is available
linux_update=false
if echo "$updates_availables" | grep -qE '^linux(-[a-z0-9]+)?\s+[0-9]'; then
    linux_update=true
    echo "linux update available"
fi

# Check if there are updates
if [ $updates_count = 0 ]; then
    echo "no updates available, cancelling update."
    exit 0
fi

# Send notification and read result
update_confirmation=$(notify-send "Updates Available" \
        "There are $updates_count pending updates" -i software-updates-symbolic \
    -a "System" -A "ok"=update)

# Confirm update
if [ "$update_confirmation" != "ok" ]; then
    echo "Update Cancelled"
    exit 0
fi

echo "Update Confirmed"
$TERMINAL -T "System Update" yay -Syu --noconfirm

if [ $linux_update = false ]; then
    echo "Linux kernel not updated. Finishing process."
    exit 0
fi

# Ask to reboot the system when linux updates

# Send notification and read result
update_confirmation=$(notify-send "Reboot the system?" \
        "The kernel has been updated.\nDo you want to reboot the system?" -i software-updates-symbolic \
    -a "System" -A "ok"=reboot -A "no"=cancel )

# Confirm reboot
if [ "$update_confirmation" = "no" ]; then
    echo "Reboot Cancelled"
    exit 0
fi

echo "Reboot Confirmed"
systemctl reboot
