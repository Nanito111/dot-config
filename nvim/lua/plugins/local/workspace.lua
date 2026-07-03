local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")
local M = {}

-- Extremos de píldora: leídos del statusline en cada render (para que la tabline
-- use el mismo borde que el statusline). Respaldo: medialunas si el statusline no
-- estuviera cargado.
local function caps()
  local ok, core = pcall(require, "plugins.local.statusline.core")
  if ok then
    return core.CAP_L, core.CAP_R
  end
  return "\u{e0b6}", "\u{e0b4}"
end

-- Colores de la tabline: cada workspace es una píldora. El relleno (fondo de la
-- tabline) usa palette.bg = fondo global del editor, leído en cada ColorScheme.
-- Por cada grupo se define su "<nombre>Sep" (fg = color del cuadro) para los extremos.
local function set_hl()
  local hl = api.nvim_set_hl
  local fill = palette.bg -- fondo de la tabline = fondo global del editor
  local function pair(name, fg, bg, opts)
    opts = opts or {}
    opts.fg, opts.bg = fg, bg
    hl(0, name, opts)
    hl(0, name .. "Sep", { fg = bg, bg = fill })
  end
  -- workspace activo: fondo brillante, texto oscuro, negrita
  pair("WsActive", palette.bg, palette.blue, { bold = true })
  -- workspaces inactivos: texto apagado sobre fondo tenue (distinto del relleno)
  pair("WsInactive", palette.blue, palette.bg_highlight)
  hl(0, "WsFill", { bg = fill })
  hl(0, "TabLineFill", { bg = fill })
end

-- Nombre visible de una tab: variable t:name, o el basename de su cwd
local function tab_name(i, tab)
  local ok, name = pcall(api.nvim_tabpage_get_var, tab, "name")
  if ok and name ~= "" then
    return name
  end
  local base = vim.fn.fnamemodify(vim.fn.getcwd(-1, i), ":t")
  return base ~= "" and base or "[sin nombre]"
end

-- Tabline personalizada: cada workspace en una píldora redondeada
function _G.tabline()
  local cur = api.nvim_get_current_tabpage()
  local CAP_L, CAP_R = caps() -- mismos extremos que el statusline
  local parts = { "%#WsFill# " }
  for i, tab in ipairs(api.nvim_list_tabpages()) do
    local hl = (tab == cur) and "WsActive" or "WsInactive"
    parts[#parts + 1] = "%" .. i .. "T" -- región clickeable con el mouse
    parts[#parts + 1] = "%#" .. hl .. "Sep#" .. CAP_L
    parts[#parts + 1] = "%#" .. hl .. "#" .. string.format(" %d \u{f07b} %s ", i, tab_name(i, tab))
    parts[#parts + 1] = "%#" .. hl .. "Sep#" .. CAP_R
    parts[#parts + 1] = "%#WsFill# " -- espacio entre píldoras
  end
  parts[#parts + 1] = "%#WsFill#%T"
  return table.concat(parts)
end

-- Crea un workspace: nueva tab con su propio cwd (tcd), nombre, explorador y dashboard
function M.new(dir)
  dir = (dir and dir ~= "") and dir or vim.fn.getcwd()
  dir = vim.fn.fnamemodify(vim.fn.expand(dir), ":p")

  vim.cmd("tabnew")
  vim.cmd("tcd " .. vim.fn.fnameescape(dir))
  api.nvim_tabpage_set_var(0, "name", vim.fn.fnamemodify(dir:gsub("[\\/]$", ""), ":t"))

  -- mismo layout que al iniciar: panel explorador + dashboard
  require("plugins.local.explorer").open()
  vim.cmd("wincmd p")
  require("plugins.local.dashboard").open()
  vim.cmd("redrawtabline")
end

-- Renombra el workspace (tab) actual
function M.rename(name)
  api.nvim_tabpage_set_var(0, "name", name)
  vim.cmd("redrawtabline")
end

-- Salta al workspace (tab) número n — el mismo número que muestra la tabline.
function M.jump(n)
  local tabs = api.nvim_list_tabpages()
  if tabs[n] then
    api.nvim_set_current_tabpage(tabs[n])
  else
    vim.notify("No existe el workspace " .. n, vim.log.levels.WARN, { title = "Workspace" })
  end
end

-- ── Buffers por workspace (tab) ────────────────────────────────────
-- Los buffers en Neovim son globales; aquí rastreamos cuáles pertenecen
-- a cada tab para que <Tab>/<S-Tab> ciclen solo dentro del workspace.
local tab_buffers = {} -- handle de tab -> lista ordenada de bufnr (archivos)
local tab_terms = {} -- handle de tab -> lista de bufnr de terminales (no flotantes)

-- ¿es un buffer de archivo normal (cicleable)?
local function is_file_buf(buf)
  return api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buflisted
    and vim.bo[buf].buftype == ""
    and api.nvim_buf_get_name(buf) ~= ""
end

-- ¿es un terminal cicleable (no flotante de claude/lazygit)?
local function is_tab_term(buf)
  return api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buftype == "terminal"
    and not vim.b[buf].term_label
end

-- Registra `buf` en `store[tab actual]` con propiedad EXCLUSIVA: pertenece a la
-- última tab donde se entró, así que se quita de las listas de las demás tabs.
local function record_exclusive(store, buf)
  local tab = api.nvim_get_current_tabpage()
  for t, list in pairs(store) do
    if t ~= tab then
      for i = #list, 1, -1 do
        if list[i] == buf then
          table.remove(list, i)
        end
      end
    end
  end
  local list = store[tab] or {}
  store[tab] = list
  for _, b in ipairs(list) do
    if b == buf then
      return
    end
  end
  list[#list + 1] = buf
end

-- Registra el buffer actual en su tab (archivo o terminal)
local function record_buffer()
  local buf = api.nvim_get_current_buf()
  if is_file_buf(buf) then
    record_exclusive(tab_buffers, buf)
  elseif is_tab_term(buf) then
    record_exclusive(tab_terms, buf)
  end
end

-- Lista de buffers válidos de la tab actual (limpiando inválidos)
local function tab_buffer_list()
  local tab = api.nvim_get_current_tabpage()
  local list = tab_buffers[tab] or {}
  local valid = {}
  for _, b in ipairs(list) do
    if is_file_buf(b) then
      valid[#valid + 1] = b
    end
  end
  tab_buffers[tab] = valid
  return valid
end

-- Expuesto para el picker: buffers (archivos) de la tab actual
M.tab_buffers = tab_buffer_list

-- Cicla entre los buffers de la tab actual (delta +1 / -1)
function M.cycle_buffer(delta)
  local list = tab_buffer_list()
  if #list == 0 then
    return
  end
  local cur = api.nvim_get_current_buf()
  local idx = 1
  for i, b in ipairs(list) do
    if b == cur then
      idx = i
      break
    end
  end
  local nidx = ((idx - 1 + delta) % #list) + 1
  api.nvim_set_current_buf(list[nidx])
end

-- Lista de terminales (no flotantes) válidos de la tab actual
function M.tab_terminals()
  local tab = api.nvim_get_current_tabpage()
  local list = tab_terms[tab] or {}
  local valid = {}
  for _, b in ipairs(list) do
    if is_tab_term(b) then
      valid[#valid + 1] = b
    end
  end
  tab_terms[tab] = valid
  return valid
end

local group = api.nvim_create_augroup("WorkspaceBuffers", { clear = true })

api.nvim_create_autocmd("BufEnter", {
  group = group,
  desc = "Registrar el buffer en su workspace",
  callback = record_buffer,
})

api.nvim_create_autocmd("TermOpen", {
  group = group,
  desc = "Registrar terminales (no flotantes) en su workspace",
  callback = function(ev)
    if is_tab_term(ev.buf) then -- excluye los flotantes (tienen term_label)
      record_exclusive(tab_terms, ev.buf)
    end
  end,
})

api.nvim_create_autocmd("TabClosed", {
  group = group,
  desc = "Limpiar buffers de tabs cerradas",
  callback = function()
    for tab in pairs(tab_buffers) do
      if not api.nvim_tabpage_is_valid(tab) then
        tab_buffers[tab] = nil
      end
    end
    for tab in pairs(tab_terms) do
      if not api.nvim_tabpage_is_valid(tab) then
        tab_terms[tab] = nil
      end
    end
  end,
})

-- Activar la tabline
theme.register(set_hl)
vim.o.showtabline = 2 -- mostrar siempre
vim.o.tabline = "%!v:lua.tabline()"

return M
