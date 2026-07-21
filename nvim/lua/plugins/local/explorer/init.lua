-- Explorador de archivos propio — plugin-free.
-- API pública y cableado. La lógica vive en los submódulos:
--   state · util · render · git · watch · actions · autocmds
local api = vim.api
local state = require("plugins.local.explorer.state")
local render = require("plugins.local.explorer.render")
local watch = require("plugins.local.explorer.watch")
local git = require("plugins.local.explorer.git")
local actions = require("plugins.local.explorer.actions")
local theme = require("config.theme")
local palette = require("config.palette")

local cur = state.cur
local states = state.states

local M = {}

-- ── Cursor oculto + línea marcada (estilo neo-tree) ────────────────
-- Dentro del explorador ocultamos el cursor y marcamos la línea actual: la línea
-- marcada pasa a ser la única señal de posición. Los grupos siguen al tema.
theme.register(function()
  api.nvim_set_hl(0, "ExplorerCursorLine", { bg = palette.bg_highlight, bold = true })
  -- cursor oculto: mismo color que la línea marcada Y que el tooltip (bg_highlight),
  -- así queda invisible sobre ambos (el cursor está en col 0, que es un espacio).
  api.nvim_set_hl(0, "ExplorerHiddenCursor", { fg = palette.bg_highlight, bg = palette.bg_highlight })
  api.nvim_set_hl(0, "ExplorerPeek", { bg = palette.bg_highlight, fg = palette.fg }) -- fondo del tooltip
  api.nvim_set_hl(0, "ExplorerBold", { bold = true }) -- negrita del item seleccionado
  api.nvim_set_hl(0, "ExplorerDim", { fg = palette.comment }) -- panel atenuado (sin foco)
  -- pestañas de la winbar del sidebar (icono de la vista activa vs la inactiva)
  api.nvim_set_hl(0, "SidebarTabOn", { fg = palette.blue, bold = true })
  api.nvim_set_hl(0, "SidebarTabOff", { fg = palette.comment })
end)

-- Filetypes que viven en el sidebar (explorador + configuración): comparten cursor
-- oculto, atenuado sin foco y la winbar de pestañas.
local SIDEBAR_FT = { explorer = true, settings = true }

-- ── Ancho / lado / auto-colapso del panel lateral ──────────────────
local DEFAULT_WIDTH = 35
local COLLAPSED_WIDTH = 6 -- ancho al perder el foco (muestra el título en vertical)
local VIEW_TITLE = { explorer = "EXPLORADOR", settings = "CONFIGURACIÓN" }
local collapsed_ns = api.nvim_create_namespace("explorer_collapsed")

function M.width()
  return require("config.settings").value("ui.sidebar_width", DEFAULT_WIDTH)
end
function M.side()
  return require("config.settings").value("ui.sidebar_side", "left")
end

-- Pinta el título de la vista en vertical (un carácter por línea, centrado)
local function render_collapsed(s)
  local buf = s.collapsed_buf
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return
  end
  local title = VIEW_TITLE[s.view] or ""
  local chars = vim.fn.split(title, "\\zs") -- por carácter (multibyte-safe)
  local h = api.nvim_win_is_valid(s.win) and api.nvim_win_get_height(s.win) or #chars
  local top = math.max(0, math.floor((h - #chars) / 2))
  local col = math.max(0, math.floor((COLLAPSED_WIDTH - 1) / 2))
  local lines = {}
  for _ = 1, top do
    lines[#lines + 1] = ""
  end
  for _, ch in ipairs(chars) do
    lines[#lines + 1] = string.rep(" ", col) .. ch
  end
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  api.nvim_buf_clear_namespace(buf, collapsed_ns, 0, -1)
  for i = top, top + #chars - 1 do
    pcall(api.nvim_buf_add_highlight, buf, collapsed_ns, "ExplorerRoot", i, 0, -1)
  end
end

-- Encoge el panel y muestra el título en vertical (solo si no tiene el foco)
local function collapse(s)
  if not (s and s.win and api.nvim_win_is_valid(s.win)) or s.collapsed then
    return
  end
  if api.nvim_get_current_win() == s.win then
    return -- enfocado: no colapsar
  end
  if not (s.collapsed_buf and api.nvim_buf_is_valid(s.collapsed_buf)) then
    s.collapsed_buf = api.nvim_create_buf(false, true)
    vim.bo[s.collapsed_buf].bufhidden = "hide"
    vim.bo[s.collapsed_buf].filetype = "explorer" -- hereda cursor oculto / sin breadcrumb
  end
  vim.wo[s.win].winbar = ""
  api.nvim_win_set_buf(s.win, s.collapsed_buf)
  -- limpiar la ventana explícitamente: el swap de buffer no dispara winopts sobre ESTA
  -- ventana (corre sobre la actual, el editor), así que sin esto el panel colapsado
  -- heredaba los números de línea del global. scope="local" para no tocar el default.
  for name, val in pairs({ number = false, relativenumber = false, signcolumn = "no", list = false, cursorline = false }) do
    pcall(api.nvim_set_option_value, name, val, { win = s.win, scope = "local" })
  end
  render_collapsed(s)
  api.nvim_win_set_width(s.win, COLLAPSED_WIDTH)
  s.collapsed = true
end

-- Restaura el panel a su ancho y contenido normal
local function expand(s)
  if not (s and s.win and api.nvim_win_is_valid(s.win)) or not s.collapsed then
    return
  end
  s.collapsed = false
  local view_buf = (s.view == "settings") and s.settings_buf or s.buf
  if view_buf and api.nvim_buf_is_valid(view_buf) then
    api.nvim_win_set_buf(s.win, view_buf)
  end
  api.nvim_win_set_width(s.win, M.width())
  M.set_winbar(s)
  if s.view == "settings" and s.settings_buf and api.nvim_buf_is_valid(s.settings_buf) then
    require("plugins.local.settings.view").attach(s.win, s.settings_buf)
  end
end

-- Reajusta el panel según el foco: expandir si es el activo, colapsar si no. Los flotantes
-- (pickers) no cuentan como "salir" del panel.
function M.refresh_sidebar()
  local s = cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) then
    return
  end
  local curwin = api.nvim_get_current_win()
  if api.nvim_win_get_config(curwin).relative ~= "" then
    return
  end
  if curwin == s.win then
    expand(s)
  else
    collapse(s)
  end
end

-- Fija (persiste + aplica) el ancho. No toca la ventana si está colapsada.
function M.set_width(w)
  require("config.settings").record("ui.sidebar_width", w, DEFAULT_WIDTH)
  local s = cur()
  if s and s.win and api.nvim_win_is_valid(s.win) and not s.collapsed then
    api.nvim_win_set_width(s.win, w)
  end
end

-- Cambia el lado (izquierda/derecha) del panel; lo mueve en vivo si está abierto.
function M.set_side(side)
  require("config.settings").record("ui.sidebar_side", side, "left")
  local s = cur()
  if s and s.win and api.nvim_win_is_valid(s.win) then
    pcall(api.nvim_win_call, s.win, function()
      vim.cmd("wincmd " .. (side == "right" and "L" or "H"))
    end)
    api.nvim_win_set_width(s.win, s.collapsed and COLLAPSED_WIDTH or M.width())
  end
end

-- Ajusta el sidebar de un tab a los ajustes globales (lado + ancho). Lo llama TabEnter: el
-- sidebar es POR TAB, y cambiar el lado/ancho desde el panel solo movía el del tab activo;
-- los demás se reconcilian al entrar a su workspace (sin cerrar/reabrir).
function M.reconcile_sidebar(s)
  s = s or cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) then
    return
  end
  local want = M.side()
  local is_left = api.nvim_win_get_position(s.win)[2] == 0
  if (want == "left") ~= is_left then
    pcall(api.nvim_win_call, s.win, function()
      vim.cmd("noautocmd wincmd " .. (want == "right" and "L" or "H"))
    end)
  end
  -- reponer el ancho SIEMPRE: wincmd L/H puede re-ensanchar la ventana (también si está
  -- colapsada, que debe conservar COLLAPSED_WIDTH)
  api.nvim_win_set_width(s.win, s.collapsed and COLLAPSED_WIDTH or M.width())
end

-- ── Negrita en el item seleccionado (línea del cursor) ─────────────
-- El bold de CursorLine no se propaga al texto (los highlights del nombre lo pisan),
-- así que aplicamos un extmark de solo-negrita sobre la línea actual, combinándose
-- con sus colores. Se mueve con el cursor.
local bold_ns = api.nvim_create_namespace("explorer_bold")
local function bold_current()
  local s = cur()
  if not (s and s.buf and api.nvim_buf_is_valid(s.buf) and s.win and api.nvim_win_is_valid(s.win)) then
    return
  end
  api.nvim_buf_clear_namespace(s.buf, bold_ns, 0, -1)
  local lnum = api.nvim_win_get_cursor(s.win)[1]
  local len = #(api.nvim_buf_get_lines(s.buf, lnum - 1, lnum, false)[1] or "")
  pcall(api.nvim_buf_set_extmark, s.buf, bold_ns, lnum - 1, 0, {
    end_col = len,
    hl_group = "ExplorerBold",
    hl_mode = "combine",
    priority = 300,
  })
end

-- ── Which-key del explorador ──────────────────────────────────────
-- Al pulsar <leader> dentro del explorador, muestra sus atajos (las teclas sueltas
-- con su descripción, leídas de los keymaps buffer-local) reusando el popup del
-- which-key; al elegir una tecla, ejecuta esa acción.
local function explorer_help()
  local entries = {}
  for _, m in ipairs(api.nvim_buf_get_keymap(0, "n")) do
    if m.desc and m.desc ~= "" and m.lhs ~= "?" then -- excluir la propia tecla de ayuda
      -- lhsraw (termcode) para que keytrans muestre "<CR>" y no "<lt>CR>"
      entries[#entries + 1] = { key = m.lhsraw or m.lhs, label = m.desc }
    end
  end
  table.sort(entries, function(a, b)
    return a.key:lower() < b.key:lower()
  end)
  local ch = require("plugins.local.whichkey.popup").read_key("Explorador", entries, true)
  if ch and ch ~= "" and ch ~= "\27" then
    api.nvim_feedkeys(ch, "m", false) -- ejecutar la acción de la tecla elegida
  end
end

-- ── Atenuar el panel cuando no tiene el foco ──────────────────────
-- Enfocado: colores vivos + línea marcada + negrita. Sin foco: todos los grupos de
-- color del explorador se remapean a ExplorerDim (gris) vía winhighlight, y se quita
-- la línea marcada y la negrita, para que el panel "se aparte".
local FOCUSED_WINHL = "CursorLine:ExplorerCursorLine"
local DIMMED_WINHL
do
  local groups = {
    "ExplorerDir", "ExplorerFile", "ExplorerCurrent", "ExplorerRoot", "ExplorerGitNew",
    "GitSignAdd", "GitSignChange", "GitSignDelete", "GitSignChangedelete",
    "GitSignStagedAdd", "GitSignStagedChange", "GitSignStagedDelete",
  }
  local parts = {}
  for _, g in ipairs(groups) do
    parts[#parts + 1] = g .. ":ExplorerDim"
  end
  DIMMED_WINHL = table.concat(parts, ",")
end

local function apply_focus(focused)
  local s = cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) then
    return
  end
  if s.view == "settings" then
    return -- la vista de configuración gestiona su propio aspecto (settings.view)
  end
  local wo = vim.wo[s.win]
  if focused then
    wo.winhighlight = FOCUSED_WINHL
    wo.cursorline = true
    bold_current()
  else
    wo.winhighlight = DIMMED_WINHL
    wo.cursorline = false
    if s.buf and api.nvim_buf_is_valid(s.buf) then
      api.nvim_buf_clear_namespace(s.buf, bold_ns, 0, -1) -- quitar la negrita del item
    end
  end
end

api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  group = api.nvim_create_augroup("ExplorerFocus", { clear = true }),
  desc = "Atenuar y colapsar/expandir el panel según el foco",
  callback = function()
    apply_focus(SIDEBAR_FT[vim.bo[api.nvim_get_current_buf()].filetype] or false)
    M.refresh_sidebar()
  end,
})

-- Al cambiar de workspace: reconciliar el sidebar de ese tab al lado/ancho configurados
-- (el ajuste desde el panel solo movió el del tab activo).
api.nvim_create_autocmd("TabEnter", {
  group = api.nvim_create_augroup("ExplorerReconcile", { clear = true }),
  callback = function()
    M.reconcile_sidebar()
  end,
})

-- ── Peek: tooltip con el nombre completo cuando la línea está cortada ──
-- Al mover el cursor en el explorador, si la línea actual es más ancha que el panel
-- (nombre largo o nivel profundo), muestra un flotante al borde derecho con el nombre
-- completo. Se oculta si cabe o al salir del explorador.
local peek_win, peek_buf
local function peek_close()
  if peek_win and api.nvim_win_is_valid(peek_win) then
    pcall(api.nvim_win_close, peek_win, true)
  end
  peek_win = nil
end

local function peek_update()
  local s = cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) or api.nvim_get_current_win() ~= s.win then
    return peek_close()
  end
  local width = api.nvim_win_get_width(s.win)
  local lnum = api.nvim_win_get_cursor(s.win)[1]
  local line = api.nvim_buf_get_lines(s.buf, lnum - 1, lnum, false)[1] or ""
  if vim.fn.strdisplaywidth(line) <= width then
    return peek_close() -- cabe: no hace falta tooltip
  end

  local text = line .. " " -- línea COMPLETA (para solaparse encima del nombre) + margen
  local w = math.min(vim.fn.strdisplaywidth(text), vim.o.columns)
  if not (peek_buf and api.nvim_buf_is_valid(peek_buf)) then
    peek_buf = api.nvim_create_buf(false, true)
  end
  vim.bo[peek_buf].modifiable = true
  api.nvim_buf_set_lines(peek_buf, 0, -1, false, { text })
  vim.bo[peek_buf].modifiable = false

  -- copiar los highlights de la línea del explorador al tooltip (colores idénticos:
  -- icono, nombre por tipo, marca de git). Como el texto es la misma línea, los
  -- offsets en bytes coinciden.
  local ns = state.ns
  api.nvim_buf_clear_namespace(peek_buf, ns, 0, -1)
  for _, m in ipairs(api.nvim_buf_get_extmarks(s.buf, ns, { lnum - 1, 0 }, { lnum - 1, -1 }, { details = true })) do
    local start_col, det = m[3], m[4]
    if det.hl_group then
      pcall(api.nvim_buf_set_extmark, peek_buf, ns, 0, start_col, {
        end_col = det.end_col,
        hl_group = det.hl_group,
      })
    end
  end
  -- el tooltip es el item seleccionado -> también en negrita
  pcall(api.nvim_buf_set_extmark, peek_buf, ns, 0, 0, {
    end_col = #text,
    hl_group = "ExplorerBold",
    hl_mode = "combine",
    priority = 300,
  })

  local cfg = {
    relative = "win",
    win = s.win,
    row = vim.fn.winline() - 1, -- fila del cursor dentro de la ventana
    col = 0, -- ENCIMA de la línea (mismo inicio que el panel), se extiende a la derecha
    width = math.max(1, w),
    height = 1,
    style = "minimal",
    border = "none", -- explícito: se superpone a la línea, sin marco (el winborder no aplica)
    focusable = false,
    noautocmd = true,
    zindex = 60,
  }
  if peek_win and api.nvim_win_is_valid(peek_win) then
    api.nvim_win_set_config(peek_win, cfg)
  else
    peek_win = api.nvim_open_win(peek_buf, false, cfg)
    vim.w[peek_win].borderless = true -- se superpone a la línea: nunca lleva marco
    vim.wo[peek_win].winhighlight = "NormalFloat:ExplorerPeek"
  end
end

local peek_group = api.nvim_create_augroup("ExplorerPeek", { clear = true })
api.nvim_create_autocmd({ "CursorMoved", "WinScrolled" }, {
  group = peek_group,
  desc = "Tooltip con el nombre completo de la línea del explorador",
  callback = function(ev)
    -- Solo actuamos en el buffer del explorador. NO cerramos en la rama contraria:
    -- reposicionar el propio tooltip dispara eventos con su buffer y cerrarlo aquí
    -- causaba el parpadeo "uno sí, uno no". El cierre lo hacen los autocmds de salida.
    if vim.bo[ev.buf].filetype == "explorer" then
      bold_current()
      peek_update()
    end
  end,
})
api.nvim_create_autocmd({ "WinLeave", "BufLeave", "CursorMovedI" }, {
  group = peek_group,
  desc = "Cerrar el tooltip del explorador al salir",
  callback = peek_close,
})

-- Ocultar el cursor al entrar al explorador y restaurarlo al salir. guicursor es
-- global, así que guardamos el valor del editor y lo devolvemos al salir.
local saved_guicursor
api.nvim_create_autocmd("BufEnter", {
  group = api.nvim_create_augroup("ExplorerCursor", { clear = true }),
  desc = "Ocultar el cursor dentro del sidebar (explorador / configuración)",
  callback = function(ev)
    if SIDEBAR_FT[vim.bo[ev.buf].filetype] then
      if not saved_guicursor then
        saved_guicursor = vim.o.guicursor
        vim.o.guicursor = "n:ExplorerHiddenCursor"
      end
    elseif saved_guicursor then
      vim.o.guicursor = saved_guicursor
      saved_guicursor = nil
    end
  end,
})

-- Abre el explorador como panel lateral izquierdo (en la tab actual)
function M.open()
  local existing = cur()
  if existing and existing.win and api.nvim_win_is_valid(existing.win) then
    api.nvim_set_current_win(existing.win)
    return
  end

  -- Tras un :ReloadConfig el estado por-tab (states) se pierde, pero la ventana del
  -- explorador anterior sigue abierta. Cerrar cualquier explorador huérfano de la
  -- tab para no acumular paneles duplicados.
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    local b = api.nvim_win_get_buf(w)
    if api.nvim_buf_is_valid(b) and SIDEBAR_FT[vim.bo[b].filetype] then
      pcall(api.nvim_win_close, w, true)
      pcall(api.nvim_buf_delete, b, { force = true })
    end
  end

  local s = { root = vim.fn.getcwd(), expanded = {}, nodes = {}, view = "explorer" }
  states[api.nvim_get_current_tabpage()] = s

  s.buf = api.nvim_create_buf(false, true)
  vim.bo[s.buf].buftype = "nofile"
  vim.bo[s.buf].bufhidden = "hide" -- sobrevive al ocultarse (lo borramos en close)
  vim.bo[s.buf].swapfile = false
  vim.bo[s.buf].filetype = "explorer"

  vim.cmd(M.side() == "right" and "botright vsplit" or "topleft vsplit")
  s.win = api.nvim_get_current_win()
  api.nvim_win_set_buf(s.win, s.buf)
  api.nvim_win_set_width(s.win, M.width())
  -- scope="local": s.win es la ventana ACTUAL, y vim.wo[curwin] sobre una opción
  -- window-local (number, cursorline…) también fija el DEFAULT GLOBAL, como :set. Eso
  -- apagaba los números en todo (y el panel de configuración leía ese global corrompido).
  local function wset(name, val)
    api.nvim_set_option_value(name, val, { win = s.win, scope = "local" })
  end
  wset("number", false)
  wset("relativenumber", false)
  wset("signcolumn", "no")
  wset("cursorline", true)
  wset("winfixwidth", true)
  wset("list", false)
  -- la línea marcada del explorador usa su propio grupo (prominente y estable,
  -- independiente del tinte por modo del cursor global)
  wset("winhighlight", "CursorLine:ExplorerCursorLine")

  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = s.buf, silent = true, nowait = true, desc = desc })
  end
  map("<CR>", actions.on_enter, "Abrir archivo / expandir carpeta")
  map("l", actions.on_enter, "Abrir archivo / expandir carpeta")
  map("h", actions.on_collapse, "Colapsar carpeta")
  map("-", actions.go_up, "Subir la raíz un nivel")
  map("R", function()
    render.render(cur())
  end, "Refrescar el árbol")
  map("q", M.close, "Cerrar el explorador")
  map("<Tab>", function() M.switch_view() end, "Cambiar a configuración")
  map("<S-Tab>", function() M.switch_view() end, "Cambiar a configuración")
  map("<leader>x", "<Nop>") -- desactivar cerrar-buffer global dentro del explorador
  -- operaciones de archivo
  map("a", actions.create, "Crear archivo/carpeta")
  map("d", actions.delete, "Borrar")
  map("r", actions.rename, "Renombrar")
  map("x", actions.cut, "Cortar")
  map("y", actions.copy, "Copiar archivo/carpeta")
  map("p", actions.paste, "Pegar")
  -- copiar ruta del nodo bajo el cursor (como tenía netrw)
  map("c", function()
    actions.copy_path(false)
  end, "Copiar ruta relativa")
  map("C", function()
    actions.copy_path(true)
  end, "Copiar ruta absoluta")
  -- which-key del explorador: ? muestra estos atajos
  map("?", explorer_help, "Atajos del explorador (which-key)")

  render.render(s)
  watch.start_watch(s)
  git.update_git(s) -- marcas de git
  M.set_winbar(s)
end

-- ── Sidebar: winbar de pestañas + cambio de vista (explorer / settings) ──
-- Iconos centrados; la vista activa resaltada. Clicables (v:lua) para saltar directo.
function M.set_winbar(s)
  if not (s and s.win and api.nvim_win_is_valid(s.win)) then
    return
  end
  local function cell(view, icon, fn)
    local hl = (s.view == view) and "%#SidebarTabOn#" or "%#SidebarTabOff#"
    return string.format("%%@v:lua.%s@ %s  %s  %%X%%*", fn, hl, icon)
  end
  local left = cell("explorer", "\u{f07b}", "__sidebar_go_explorer") --
  local right = cell("settings", "\u{f013}", "__sidebar_go_settings") --
  vim.wo[s.win].winbar = "%=" .. left .. right .. "%="
end

-- Muestra una vista en la ventana del sidebar (intercambia el buffer, no la ventana)
function M.show_view(view)
  local s = cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) then
    return
  end
  api.nvim_set_current_win(s.win)
  if view == "settings" then
    local sv = require("plugins.local.settings.view")
    if not (s.settings_buf and api.nvim_buf_is_valid(s.settings_buf)) then
      s.settings_buf = sv.create()
    end
    api.nvim_win_set_buf(s.win, s.settings_buf)
    s.view = "settings"
    sv.attach(s.win, s.settings_buf)
  else
    api.nvim_win_set_buf(s.win, s.buf)
    s.view = "explorer"
    apply_focus(true)
  end
  M.set_winbar(s)
end

-- <Tab>: alterna entre explorador y configuración
function M.switch_view()
  local s = cur()
  if not s then
    return
  end
  M.show_view(s.view == "explorer" and "settings" or "explorer")
end

-- Abre el sidebar (si hace falta) directamente en la vista de configuración
function M.open_settings()
  M.open()
  M.show_view("settings")
end

function _G.__sidebar_go_explorer()
  require("plugins.local.explorer").show_view("explorer")
end
function _G.__sidebar_go_settings()
  require("plugins.local.explorer").show_view("settings")
end

function M.close()
  local s = cur()
  if not s then
    return
  end
  watch.stop_watch(s)
  for _, t in ipairs({ "timer", "git_timer" }) do
    if s[t] then
      pcall(function()
        s[t]:stop()
        s[t]:close()
      end)
      s[t] = nil
    end
  end
  if s.win and api.nvim_win_is_valid(s.win) then
    api.nvim_win_close(s.win, true)
  end
  for _, b in ipairs({ s.buf, s.settings_buf, s.collapsed_buf }) do -- bufhidden=hide no se borran solos
    if b and api.nvim_buf_is_valid(b) then
      pcall(api.nvim_buf_delete, b, { force = true })
    end
  end
  states[api.nvim_get_current_tabpage()] = nil
end

function M.toggle()
  local s = cur()
  if s and s.win and api.nvim_win_is_valid(s.win) then
    M.close()
  else
    M.open()
  end
end

-- Alterna el FOCO entre el explorador y la edición (como el viejo <leader>e)
function M.focus()
  local s = cur()
  if not (s and s.win and api.nvim_win_is_valid(s.win)) then
    M.open() -- no está abierto: abrir (queda enfocado)
    return
  end
  if api.nvim_get_current_win() == s.win then
    -- estoy en el explorador -> ir a una ventana de edición
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
      if w ~= s.win and api.nvim_win_get_config(w).relative == "" and not vim.wo[w].winfixwidth then
        api.nvim_set_current_win(w)
        return
      end
    end
  else
    api.nvim_set_current_win(s.win)
  end
end

-- Re-enraíza el explorador de la tab actual al cwd (para tcd/cambio de tab)
function M.follow()
  local s = cur()
  if s and s.win and api.nvim_win_is_valid(s.win) and s.root ~= vim.fn.getcwd() then
    s.root = vim.fn.getcwd()
    render.render(s)
    watch.start_watch(s)
    git.update_git(s)
  end
end

require("plugins.local.explorer.autocmds") -- registra los autocomandos

return M
