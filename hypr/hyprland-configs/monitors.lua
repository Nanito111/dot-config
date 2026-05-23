-- hyprland-configs/monitors.lua
-- Migrated from monitors.conf

-- Default monitor fallback
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Zoran HDMI TV
hl.monitor({
    output   = "desc:Zoran Corporation ZORAN HDMI TV 0x00000001",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Nreal glasses
hl.monitor({
    output   = "desc: Nreal MGMG2710C",
    mode     = "1920x1080@120",
    position = "auto",
    scale    = 1,
})

-- Samsung LF24T450F
hl.monitor({
    output   = "desc: Samsung Electric Company LF24T450F HCPX700137",
    mode     = "1920x1080@60",
    position = "auto-right",
    scale    = 1,
})
