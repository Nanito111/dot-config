local api = vim.api
local autocmd = api.nvim_create_autocmd
local icons = require("config.icons")
local palette = require("config.palette")
local theme = require("config.theme")

-- Nombres legibles de cada modo
local modes = {
  n = "NORMAL",
  no = "OP-PENDING",
  v = "VISUAL",
  V = "V-LINE",
  ["\22"] = "V-BLOCK", -- <C-v>
  s = "SELECT",
  S = "S-LINE",
  ["\19"] = "S-BLOCK", -- <C-s>
  i = "INSERT",
  ic = "INSERT",
  R = "REPLACE",
  Rv = "V-REPLACE",
  c = "COMMAND",
  cv = "EX",
  r = "PROMPT",
  rm = "MORE",
  ["r?"] = "CONFIRM",
  ["!"] = "SHELL",
  t = "TERMINAL",
}

-- Ancho fijo del cuadro de modo = etiqueta más larga (para que no cambie de tamaño)
local MODE_W = 0
for _, name in pairs(modes) do
  MODE_W = math.max(MODE_W, #name)
end

-- Ajusta `s` a un ancho fijo `w` (rellena con espacios o trunca).
-- align: "l" izquierda (def.), "r" derecha, "c" centro.
local function fit(s, w, align)
  local len = vim.fn.strdisplaywidth(s)
  if len > w then
    s = vim.fn.strcharpart(s, 0, w)
    len = w
  end
  local pad = w - len
  if align == "r" then
    return string.rep(" ", pad) .. s
  elseif align == "c" then
    local l = math.floor(pad / 2)
    return string.rep(" ", l) .. s .. string.rep(" ", pad - l)
  end
  return s .. string.rep(" ", pad)
end

-- Centra la etiqueta del modo en el ancho fijo
local function mode_label(m)
  return fit(modes[m] or m:upper(), MODE_W, "c")
end

-- Grupo de resaltado según el modo
local function mode_color(m)
  local c = m:sub(1, 1)
  if c == "i" then
    return "StInsert"
  elseif c == "v" or c == "V" or c == "\22" or c == "s" or c == "S" or c == "\19" then
    return "StVisual"
  elseif c == "R" then
    return "StReplace"
  elseif c == "c" or c == "!" then
    return "StCommand"
  elseif c == "t" then
    return "StTerminal"
  end
  return "StNormal"
end

-- Fondo de la statusline (sobre el que flotan las píldoras)
local FILL = palette.bg_dark

-- Caracteres Powerline de media-luna para los extremos redondeados
local CAP_L = "\u{e0b6}" --
local CAP_R = "\u{e0b4}" --

-- Colores de la statusline (estilo tokyonight). Por cada cuadro se define su
-- grupo y un grupo "<nombre>Sep" para las medialunas (fg = color del cuadro).
local function set_hl()
  local hl = api.nvim_set_hl
  local function pair(name, fg, bg, opts)
    opts = opts or {}
    opts.fg, opts.bg = fg, bg
    hl(0, name, opts)
    hl(0, name .. "Sep", { fg = bg, bg = FILL })
  end
  pair("StNormal", palette.bg, palette.blue, { bold = true })
  pair("StInsert", palette.bg, palette.green, { bold = true })
  pair("StVisual", palette.bg, palette.purple, { bold = true })
  pair("StReplace", palette.bg, palette.red, { bold = true })
  pair("StCommand", palette.bg, palette.yellow, { bold = true })
  pair("StTerminal", palette.bg, palette.cyan, { bold = true })
  pair("StGit", palette.blue, palette.bg_highlight)
  pair("StFile", palette.fg, palette.bg_highlight)
  pair("StInfo", palette.fg, palette.bg_highlight)
  hl(0, "StFill", { bg = FILL })
  hl(0, "StatusLine", { bg = FILL }) -- base de la línea
end

-- Envuelve `content` en una píldora con extremos redondeados del color `hl`
local function pill(hl, content)
  return "%#" .. hl .. "Sep#" .. CAP_L .. "%#" .. hl .. "#" .. content .. "%#" .. hl .. "Sep#" .. CAP_R
end

-- Etiqueta de la statusline: solo para buffers especiales (terminal/explorador)
-- y [No Name]. Los archivos con nombre muestran su ruta en el winbar (breadcrumbs).
local function filename()
  local ft = vim.bo.filetype
  if ft == "explorer" then
    return "explorador"
  elseif ft == "dashboard" then
    return ""
  elseif vim.bo.buftype == "terminal" then
    return vim.b.term_label or vim.b.term_name or "terminal"
  end
  local name = api.nvim_buf_get_name(0)
  if name == "" then
    return "[No Name]"
  end
  return "" -- archivo con nombre: lo muestra el winbar
end

-- Anchos fijos de cada cuadro
local GIT_W, FT_W, POS_W, PCT_W = 16, 8, 9, 4

-- Construye la statusline (evaluada en cada redraw)
function _G.statusline()
  local m = api.nvim_get_mode().mode
  local color = mode_color(m)

  -- git (ancho fijo cuando hay rama)
  local branch = vim.b.gitbranch
  local git = ""
  if branch and branch ~= "" then
    git = pill("StGit", " " .. fit("\u{e0a0} " .. branch, GIT_W, "l") .. " ")
  end

  -- filetype: icono + extensión corta (en vez del nombre completo del lenguaje)
  local ft
  if vim.bo.buftype == "terminal" then
    ft = "\u{f489} term"
  elseif vim.bo.filetype == "explorer" then
    ft = "\u{f07b} files"
  else
    local fname = api.nvim_buf_get_name(0)
    local short = icons.ext(fname) or (vim.bo.filetype ~= "" and vim.bo.filetype) or "—"
    ft = icons.icon(fname) .. " " .. short
  end

  -- posición y porcentaje (calculados en Lua para ancho fijo)
  local cur = api.nvim_win_get_cursor(0)
  local total = api.nvim_buf_line_count(0)
  local pct = (total > 1) and math.floor((cur[1] - 1) / (total - 1) * 100) or 0
  local linecol = cur[1] .. ":" .. (cur[2] + 1)
  local pctstr = fit(pct .. "%", PCT_W, "r"):gsub("%%", "%%%%") -- escapar el %

  -- etiqueta solo para buffers especiales (los archivos van en el winbar)
  local label = filename()
  local fileseg = (label ~= "") and pill("StFile", " " .. label .. " ") or ""

  local sp = "%#StFill# " -- espacio entre píldoras sobre el fondo de la línea
  return table.concat({
    "%#StFill#", -- base de la línea
    -- izquierda: git + etiqueta (terminal/explorador); los archivos van al winbar
    git,
    (git ~= "" and fileseg ~= "") and sp or "",
    fileseg,
    "%#StFill#%=", -- relleno hasta el centro
    -- centro: cuadro de modo
    pill(color, " " .. mode_label(m) .. " "),
    "%#StFill#%=", -- relleno hasta la derecha
    -- derecha: filetype + posición + porcentaje (anchos fijos)
    pill("StInfo", " " .. fit(ft, FT_W, "c") .. " "),
    sp,
    pill("StInfo", " " .. fit(linecol, POS_W, "r") .. " "),
    sp,
    pill(color, " " .. pctstr .. " "),
    "%#StFill# ",
  })
end

-- Rama de git: se calcula async y se cachea en vim.b.gitbranch
local function update_git(buf)
  if vim.fn.executable("git") == 0 then
    return
  end
  buf = buf or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(buf) then
    return -- el buffer pudo invalidarse (p. ej. al refrescar netrw en DirChanged)
  end
  local name = api.nvim_buf_get_name(buf)
  local dir = name ~= "" and vim.fn.fnamemodify(name, ":h") or vim.fn.getcwd()

  vim.system(
    { "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" },
    { text = true },
    function(res)
      local branch = (res.code == 0) and vim.trim(res.stdout or "") or ""
      vim.schedule(function()
        if api.nvim_buf_is_valid(buf) and vim.b[buf].gitbranch ~= branch then
          vim.b[buf].gitbranch = branch
          vim.cmd("redrawstatus")
        end
      end)
    end
  )
end

-- Activar
theme.register(set_hl)
vim.o.laststatus = 3 -- una sola statusline global
vim.o.statusline = "%!v:lua.statusline()"

local group = api.nvim_create_augroup("Statusline", { clear = true })

autocmd({ "BufEnter", "FocusGained", "DirChanged", "BufWritePost" }, {
  group = group,
  desc = "Actualizar rama de git",
  callback = function(ev)
    update_git(ev.buf)
  end,
})
