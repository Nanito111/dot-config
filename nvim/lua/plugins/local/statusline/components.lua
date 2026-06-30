-- Componentes de la statusline. Cada uno es  ctx -> segmento | nil.
-- Para añadir uno nuevo: define la función aquí y agrégalo al LAYOUT en init.lua.
local api = vim.api
local icons = require("config.icons")
local cfg = require("plugins.local.statusline.config")

local M = {}

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

-- Grupo de resaltado según el modo (también lo usa el % de la derecha)
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

-- Contexto compartido, calculado una vez por render (lo recibe cada componente)
function M.context()
  local m = api.nvim_get_mode().mode
  return { mode = m, color = mode_color(m) }
end

-- ── Componentes ────────────────────────────────────────────────────
M.components = {
  -- cuadro de modo (centro), coloreado según el modo
  mode = function(ctx)
    return { text = modes[ctx.mode] or ctx.mode:upper(), hl = ctx.color, width = MODE_W, align = "c" }
  end,

  -- rama de git (la cachea init en vim.b.gitbranch); se oculta si no hay
  git = function()
    local b = vim.b.gitbranch
    if not b or b == "" then
      return nil
    end
    return { text = cfg.icons.branch .. " " .. b, hl = "StGit", width = cfg.width.git, align = "l" }
  end,

  -- etiqueta solo para buffers especiales (terminal/explorador) y [No Name];
  -- los archivos con nombre muestran su ruta en el winbar (breadcrumbs)
  label = function()
    local ft = vim.bo.filetype
    local text
    if ft == "explorer" then
      text = "explorador"
    elseif ft == "dashboard" then
      return nil
    elseif vim.bo.buftype == "terminal" then
      text = vim.b.term_label or vim.b.term_name or "terminal"
    else
      local name = api.nvim_buf_get_name(0)
      if name == "" then
        text = "[No Name]"
      else
        return nil -- archivo con nombre: lo muestra el winbar
      end
    end
    return { text = text, hl = "StFile" }
  end,

  -- filetype: icono + extensión corta (o term/files para buffers especiales)
  filetype = function()
    local ft
    if vim.bo.buftype == "terminal" then
      ft = cfg.icons.terminal .. " term"
    elseif vim.bo.filetype == "explorer" then
      ft = cfg.icons.files .. " files"
    else
      local fname = api.nvim_buf_get_name(0)
      local short = icons.ext(fname) or (vim.bo.filetype ~= "" and vim.bo.filetype) or "—"
      ft = icons.icon(fname) .. " " .. short
    end
    return { text = ft, hl = "StInfo", width = cfg.width.filetype, align = "c" }
  end,

  -- servidor(es) LSP conectados al buffer; se oculta si no hay ninguno
  lsp = function()
    local names = {}
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
      names[#names + 1] = c.name
    end
    if #names == 0 then
      return nil
    end
    return { text = cfg.icons.lsp .. " " .. table.concat(names, ","), hl = "StInfo", align = "l" }
  end,

  -- conteo de diagnósticos del buffer (errores/avisos/info/pistas); se oculta si no
  -- hay ninguno. Una sola píldora coloreada según la severidad más alta presente.
  diagnostics = function()
    local sev = vim.diagnostic.severity
    local c = vim.diagnostic.count(0)
    local e, w, i, h = c[sev.ERROR] or 0, c[sev.WARN] or 0, c[sev.INFO] or 0, c[sev.HINT] or 0
    if e + w + i + h == 0 then
      return nil
    end
    local parts = {}
    if e > 0 then parts[#parts + 1] = cfg.icons.diag_error .. " " .. e end
    if w > 0 then parts[#parts + 1] = cfg.icons.diag_warn .. " " .. w end
    if i > 0 then parts[#parts + 1] = cfg.icons.diag_info .. " " .. i end
    if h > 0 then parts[#parts + 1] = cfg.icons.diag_hint .. " " .. h end
    local hl = (e > 0 and "StDiagError") or (w > 0 and "StDiagWarn") or (i > 0 and "StDiagInfo") or "StDiagHint"
    return { text = table.concat(parts, " "), hl = hl, align = "l" }
  end,

  -- posición línea:columna
  position = function()
    local cur = api.nvim_win_get_cursor(0)
    return { text = cur[1] .. ":" .. (cur[2] + 1), hl = "StInfo", width = cfg.width.position, align = "r" }
  end,

  -- porcentaje de avance en el archivo, coloreado según el modo
  percent = function(ctx)
    local cur = api.nvim_win_get_cursor(0)
    local total = api.nvim_buf_line_count(0)
    local pct = (total > 1) and math.floor((cur[1] - 1) / (total - 1) * 100) or 0
    return { text = pct .. "%", hl = ctx.color, width = cfg.width.percent, align = "r" }
  end,
}

return M
