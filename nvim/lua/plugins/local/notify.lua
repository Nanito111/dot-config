-- Notificaciones como toast (plugin-free): sobrescribe vim.notify para mostrar
-- ventanas flotantes arriba a la derecha, apilables y auto-cerrables, con color e
-- icono por nivel. Guarda historial y lo expone con :Notifications.
local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")
local levels = vim.log.levels

local M = {}

-- ── Colores por nivel ──────────────────────────────────────────────
local function set_hl()
  local hl = api.nvim_set_hl
  hl(0, "NotifyInfo", { fg = palette.blue })
  hl(0, "NotifyWarn", { fg = palette.yellow })
  hl(0, "NotifyError", { fg = palette.red })
  hl(0, "NotifyDebug", { fg = palette.comment })
end
theme.register(set_hl)

-- nivel -> { grupo de color, icono, duración (ms) }
local LEVELS = {
  [levels.TRACE] = { hl = "NotifyDebug", icon = "\u{f0e7}", timeout = 3000 },
  [levels.DEBUG] = { hl = "NotifyDebug", icon = "\u{f188}", timeout = 3000 },
  [levels.INFO] = { hl = "NotifyInfo", icon = "\u{f05a}", timeout = 3000 },
  [levels.WARN] = { hl = "NotifyWarn", icon = "\u{f071}", timeout = 4000 },
  [levels.ERROR] = { hl = "NotifyError", icon = "\u{f057}", timeout = 5000 },
}

local MAX_W = 60 -- ancho máximo del toast
local active = {} -- toasts en pantalla (de arriba a abajo)
local history = {} -- { { msg, level, time, hl, icon } }, máx 100

-- ── Utilidades ─────────────────────────────────────────────────────
-- Parte un texto en líneas y envuelve las que pasen de `w` columnas
local function to_lines(msg, w)
  local out = {}
  for line in (msg .. "\n"):gmatch("(.-)\n") do
    if line == "" then
      out[#out + 1] = ""
    else
      while vim.fn.strdisplaywidth(line) > w do
        out[#out + 1] = vim.fn.strcharpart(line, 0, w)
        line = vim.fn.strcharpart(line, w)
      end
      out[#out + 1] = line
    end
  end
  return out
end

-- Recoloca todos los toasts activos apilados desde arriba a la derecha
local function reflow()
  local row = 1
  for _, t in ipairs(active) do
    if t.win and api.nvim_win_is_valid(t.win) then
      api.nvim_win_set_config(t.win, {
        relative = "editor",
        anchor = "NE",
        row = row,
        col = vim.o.columns - 1,
        width = t.width,
        height = t.height,
      })
      row = row + t.height + 2 -- alto + bordes + hueco
    end
  end
end

local function dismiss(toast)
  if toast.dismissed then
    return -- evitar doble cierre (timer + cierre manual)
  end
  toast.dismissed = true
  if toast.timer then
    pcall(function()
      toast.timer:stop()
      toast.timer:close()
    end)
  end
  for i, t in ipairs(active) do
    if t == toast then
      table.remove(active, i)
      break
    end
  end
  if toast.win and api.nvim_win_is_valid(toast.win) then
    pcall(api.nvim_win_close, toast.win, true)
  end
  reflow()
end

-- Descarta TODOS los toasts visibles ahora mismo (el historial se conserva)
function M.dismiss_all()
  local copy = {}
  for i, t in ipairs(active) do
    copy[i] = t
  end
  for _, t in ipairs(copy) do
    dismiss(t)
  end
end

-- ── Mostrar un toast ───────────────────────────────────────────────
local function show(msg, level, opts)
  opts = opts or {}
  level = level or levels.INFO
  local L = LEVELS[level] or LEVELS[levels.INFO]

  -- historial
  history[#history + 1] = { msg = msg, level = level, time = os.date("%H:%M:%S"), hl = L.hl, icon = L.icon }
  if #history > 100 then
    table.remove(history, 1)
  end

  local lines = to_lines(msg, MAX_W)
  local body = {}
  local width = 1
  for _, l in ipairs(lines) do
    body[#body + 1] = " " .. l
    width = math.max(width, vim.fn.strdisplaywidth(l) + 1)
  end

  local title = string.format(" %s %s ", L.icon, opts.title or "")
  width = math.min(MAX_W + 2, math.max(width + 1, vim.fn.strdisplaywidth(title)))

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, body)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = api.nvim_open_win(buf, false, {
    relative = "editor",
    anchor = "NE",
    row = 1,
    col = vim.o.columns - 1,
    width = width,
    height = #body,
    style = "minimal",
    title = title,
    title_pos = "left",
    focusable = false,
    noautocmd = true,
    zindex = 200,
  })
  vim.wo[win].winhighlight = "NormalFloat:NormalFloat,FloatBorder:" .. L.hl .. ",FloatTitle:" .. L.hl
  vim.wo[win].wrap = false

  local toast = { win = win, height = #body, width = width }
  active[#active + 1] = toast
  reflow()

  toast.timer = vim.defer_fn(function()
    dismiss(toast)
  end, opts.timeout or L.timeout)
end

-- ── Override de vim.notify ─────────────────────────────────────────
-- Se ejecuta en vim.schedule para ser seguro desde contextos async/fast.
vim.notify = function(msg, level, opts)
  if type(msg) == "table" then
    msg = table.concat(msg, "\n")
  end
  msg = tostring(msg)
  vim.schedule(function()
    show(msg, level, opts)
  end)
end

-- ── Historial (:Notifications) ─────────────────────────────────────
function M.show_history()
  if #history == 0 then
    vim.notify("Sin notificaciones todavía")
    return
  end
  local lines, hls = {}, {}
  for i = #history, 1, -1 do -- más reciente arriba
    local h = history[i]
    local first = true
    for _, l in ipairs(to_lines(tostring(h.msg), MAX_W)) do
      if first then
        lines[#lines + 1] = string.format(" %s %s  %s", h.time, h.icon, l)
        first = false
      else
        lines[#lines + 1] = "            " .. l
      end
      hls[#hls + 1] = h.hl
    end
  end

  local width = 1
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.min(width + 1, math.floor(vim.o.columns * 0.8))
  local height = math.min(#lines, math.floor(vim.o.lines * 0.6))

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local ns = api.nvim_create_namespace("notify_history")
  for i, hl in ipairs(hls) do
    api.nvim_buf_add_highlight(buf, ns, hl, i - 1, 0, -1)
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    title = " Notificaciones ",
    title_pos = "center",
  })
  -- scope="local": win es la ventana actual; sin él fijaría el default global de cursorline
  api.nvim_set_option_value("cursorline", true, { win = win, scope = "local" })
  for _, k in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", k, function()
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true })
  end
end

-- Vacía el historial (no afecta los toasts en pantalla)
function M.clear_history()
  history = {}
end

api.nvim_create_user_command("Notifications", M.show_history, {
  desc = "Ver el historial de notificaciones",
})

api.nvim_create_user_command("NotificationsClear", function(o)
  M.dismiss_all() -- cerrar los toasts visibles
  if o.bang then
    M.clear_history() -- :NotificationsClear! también borra el historial
  end
end, {
  bang = true,
  desc = "Cerrar los toasts visibles (con ! también borra el historial)",
})

-- Recolocar al redimensionar (la columna derecha cambia)
api.nvim_create_autocmd("VimResized", {
  group = api.nvim_create_augroup("Notify", { clear = true }),
  callback = reflow,
})

return M
