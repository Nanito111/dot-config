#!/bin/fish

set updates_count $(checkupdates | wc -l)

if test $updates_count -gt 0
  notify-send "Updates Available" "The are $updates_count pending updates" \
    -i software-updates-symbolic -t 7000
end

set -e updates_count
