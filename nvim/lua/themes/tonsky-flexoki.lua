-- Credits to original theme https://github.com/kepano/flexoki/
-- Highlight idea from https://tonsky.me/blog/syntax-highlighting/

local M = {}

M.base_30 = {
  darker_black = "#171616",
  black = "#100F0F", --  bg (nvim bg)
  black2 = "#1C1B1A", -- bg2 (secondary bg)
  one_bg = "#282726", -- ui (borders)
  one_bg2 = "#343331", -- ui2 (hovered borders)
  one_bg3 = "#403E3C", -- ui3 (active borders)
  grey = "#575653", -- tx3 (faint text)
  grey_fg = "#6F6E69",
  grey_fg2 = "#878580", -- tx2 (muted text)
  light_grey = "#B7B5AC",
  white = "#CECDC3", -- tx1
  red = "#D14D41",
  baby_pink = "#d36da1",
  pink = "#CE5D97",
  green = "#879A39",
  vibrant_green = "#7e9f0e",
  nord_blue = "#4385BE",
  blue = "#4385BE",
  yellow = "#D0A215",
  sun = "#eabb2b",
  purple = "#8B7EC8",
  dark_purple = "#7f70c2",
  teal = "#519ABA",
  orange = "#DA702C",
  cyan = "#3AA99F",
  statusline_bg = "#171616",
  lightbg = "#292626",
  pmenu_bg = "#3AA99F",
}
M.base_30.folder_bg = M.base_30.white
M.base_30.line = M.base_30.one_bg -- for lines like vertsplit

M.base_16 = {
  base00 = M.base_30.black,
  base01 = M.base_30.black2,
  base02 = M.base_30.one_bg,
  base03 = M.base_30.grey,
  base04 = M.base_30.grey_fg,
  base05 = M.base_30.white,
  base06 = "#b6bdca",
  base07 = "#c8ccd4",
  base08 = M.base_30.red,
  base09 = M.base_30.orange,
  base0A = M.base_30.purple,
  base0B = M.base_30.green,
  base0C = M.base_30.cyan,
  base0D = M.base_30.blue,
  base0E = M.base_30.yellow,
  base0F = M.base_30.teal,
}

local custom_colors = {
  keyword = M.base_30.grey_fg2,
  include = M.base_30.grey_fg2,
  operator = M.base_30.grey_fg2,
  constructor = M.base_30.grey_fg2,
  punctuation = M.base_30.grey_fg2,

  tag = M.base_30.white,
  type = M.base_30.white,
  boolean = M.base_30.white,
  module = M.base_30.white,
  call = M.base_30.white,
  variable = M.base_30.white,
  member = M.base_30.white,
  property = M.base_30.white,
  attribute = M.base_30.white,

  special = M.base_30.white,
  specialChar = M.base_30.white,

  comment = M.base_30.green,
  number = M.base_30.purple,
  functions = M.base_30.orange,
  string = M.base_30.cyan,
  parameter = M.base_30.blue,
  constant = M.base_30.yellow,
}

M.polish_hl = {
  tbline = {
    TbFill = { bg = "NONE" },
    TbBufOn = { fg = M.base_30.white, bg = M.base_30.black, bold = true },
    TbBufOnClose = { fg = M.base_30.red, bg = M.base_30.black },
    TbBufOff = { fg = M.base_30.one_bg2, bg = "NONE" },
    TbBufOffClose = { bg = "NONE" },
    TbBufOnModified = { fg = M.base_30.green, bg = M.base_30.black },
    TbBufOffModified = { fg = M.base_30.red, bg = "NONE" },
  },
  nvimtree = {
    NvimTreeNormal = { bg = M.base_30.black },
    NvimTreeNormalNC = { bg = M.base_30.black },
  },
  telescope = {
    TelescopeResultsNormal = { fg = M.base_30.grey_fg2 },
    TelescopeSelection = { fg = M.base_30.white, bold = true },
    TelescopeMatching = { fg = M.base_30.green, bg = "NONE" },
  },
  syntax = {
    Keyword = { fg = custom_colors.keyword },
    Include = { fg = custom_colors.include },
    Tag = { fg = custom_colors.tag },
    Type = { fg = custom_colors.type },
    Special = { fg = custom_colors.special },
    SpecialChar = { fg = custom_colors.specialChar },
    Boolean = { fg = custom_colors.boolean },
    CursorLine = { bg = "NONE" },
    Comment = { fg = custom_colors.comment },
    Number = { fg = custom_colors.number },
    String = { fg = custom_colors.string },
    Identifier = { fg = custom_colors.variable },
    Title = { fg = custom_colors.constructor },
  },
  treesitter = {
    ["@keyword"] = { fg = custom_colors.keyword },
    ["@keyword.return"] = { fg = custom_colors.keyword },
    ["@keyword.conditional"] = { fg = custom_colors.keyword },
    ["@keyword.operator"] = { fg = custom_colors.keyword },
    ["@keyword.function"] = { fg = custom_colors.keyword },
    ["@keyword.repeat"] = { fg = custom_colors.keyword },
    ["@keyword.exception"] = { fg = custom_colors.keyword },

    ["@constant"] = { fg = custom_colors.constant },
    ["@variable"] = { fg = custom_colors.variable },
    ["@variable.member"] = { fg = custom_colors.member },
    ["@variable.parameter"] = { fg = custom_colors.parameter },
    ["@attribute"] = { fg = custom_colors.attribute },
    ["@property"] = { fg = custom_colors.property },

    ["@tag.attribute"] = { fg = custom_colors.tag },
    ["@tag"] = { fg = custom_colors.tag },

    ["@string"] = { fg = custom_colors.string },
    ["@string.special.url"] = { bg = custom_colors.string },
    ["@markup.link.url"] = { bg = custom_colors.string },

    ["@punctuation.bracket"] = { fg = custom_colors.punctuation },
    ["@punctuation.delimiter"] = { fg = custom_colors.punctuation },

    ["@operator"] = { fg = custom_colors.operator },
    ["@constructor"] = { fg = custom_colors.constructor },

    ["@function.call"] = { fg = custom_colors.call },
    ["@function.method.call"] = { fg = custom_colors.call },
    ["@function.builtin"] = { fg = custom_colors.keyword },
    ["@constant.builtin"] = { fg = custom_colors.keyword },

    ["@type.builtin"] = { fg = custom_colors.type },
    ["@type"] = { fg = custom_colors.type },

    ["@number"] = { fg = custom_colors.number },
    ["@number.float"] = { fg = custom_colors.number },

    ["@comment"] = { fg = custom_colors.comment },
    ["@function"] = { fg = custom_colors.functions },
    ["@module"] = { fg = custom_colors.module },
  },
}

M.type = "dark"

M = require("base46").override_theme(M, "tonsky-flexoki")

return M
