#!/bin/fish

set -l updates_count $(count (checkupdates && yay -Qua))

if test $updates_count -gt 0
  # send notification and read result of notification
  notify-send "Updates Available" "The are $updates_count pending updates" \
    -i software-updates-symbolic -a "System" -A "ok"=update \
    | read -l update_confirmation

  if test "$update_confirmation" = "ok"
    echo "Update Confirmed"
    uwsm app -- foot yay -Syu
  else
    echo "Update Cancelled"
  end
end

set -e updates_count
