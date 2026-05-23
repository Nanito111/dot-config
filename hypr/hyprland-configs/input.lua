-- hyprland-configs/input.lua
-- Migrated from input.conf

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "altgr-intl",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        repeat_rate  = 60,
        repeat_delay = 200,

        -- 0 - Cursor movement will not change focus.
        -- 1 - Cursor movement will always change focus to the window under the cursor.
        -- 2 - Cursor focus will be detached from keyboard focus.
        -- 3 - Cursor focus completely separate from keyboard focus.
        follow_mouse   = 1,
        accel_profile  = "flat",
        sensitivity    = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },

        tablet = {
            output         = "current",
            relative_input = false,
        },
    },
})
