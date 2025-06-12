#!/bin/bash

# Count available updates
updates_count=$($(checkupdates && yay -Qua) | wc -l)


# Check if there are updates
if [ $updates_count -gt 0 ]; then
  # Send notification and read result
  update_confirmation=$(notify-send "Updates Available" "There are $updates_count pending updates" \
    -i software-updates-symbolic -a "System" -A "ok"=update)

  # Confirm update
  if [ "$update_confirmation" = "ok" ]; then
    echo "Update Confirmed"
    uwsm app -- foot yay -Syu
  else
    echo "Update Cancelled"
  fi
fi
