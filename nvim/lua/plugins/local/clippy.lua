-- Clippy: mascota-asistente (plugin-free) que DEAMBULA por la pantalla, siempre por encima
-- de todo, y suelta un globo de diálogo al reaccionar (errores del LSP, guardar, tips al
-- estar inactivo). Off por defecto; <leader>pp lo alterna, <leader>pt suelta un tip.
local api = vim.api
local M = {}

-- local MASCOT = vim.fn.nr2char(0xF014F) -- 󰅏 clip de Nerd Font
local MASCOT = {
  "╭─╮╮",
  "o O│",
  "│╰╯│",
  "╰──╯"
}
local MASCOT_W = 4                       -- ancho en celdas
local MASCOT_H = #MASCOT                 -- alto (nº de filas)
local Z = 250                            -- zindex: por encima de splits y flotantes normales
local STEP_MS = 10                       -- ms entre pasos mientras se mueve (menor = más rápido)
local PAUSE_MIN, PAUSE_MAX = 5000, 10000 -- ms quieto al llegar a un destino (sin gastar CPU)
local BUBBLE_W = 42
local SHOW_MS = 3000                   -- cuánto queda visible el bocadillo
local TIP_GAP = 30                     -- segundos mínimos entre tips por inactividad

local m_win, m_buf                     -- mascota
local b_win, b_buf                     -- bocadillo
local t_win, t_buf                     -- cola del bocadillo
local move_timer, hide_timer
local enabled = false
local last_tip = 0
local pos = { row = 5, col = 5 }
local target = { row = 5, col = 5 }
local dragging = false
local drag_off = { row = 0, col = 0 }

local GREET = "¡Hola! Soy Clippy, tu asistente. Andaré por aquí."
local PRAISE = { "¡Guardado! 💾", "Buen trabajo, sigue así ✨", "Todo en orden." }
local WS_LINES = {
  WorkspaceNew = {
    "¡Workspace '%s' listo! A estrenarlo.",
    "Nuevo espacio '%s'. Empezamos de cero.",
    "Creaste '%s'. Me mudo contigo.",
  },
  WorkspaceRenamed = {
    "Ahora esto se llama '%s'. Anotado.",
    "'%s', buen nombre.",
  },
  WorkspaceSwitch = {
    "Te moviste a '%s'. Te sigo.",
    "Cambiando de aires: '%s'.",
    "En '%s' ahora. ¿Qué toca?",
  },
  WorkspaceMoved = {
    "Reordenando workspaces, muy prolijo.",
    "'%s' cambió de lugar. Ordenadito.",
  },
}

local function pick(t)
  return t[math.random(#t)]
end

-- Frase al azar, tirando de lo que está pasando ahora mismo (archivo, lenguaje,
-- posición, cambios sin guardar, avisos del LSP, hora) para que parezca al tanto.
-- Qué corre en un buffer de terminal: mira nombre del buffer + título del terminal
-- (que el programa actualiza) + el nombre que le pusimos nosotros.
local function term_kind(buf)
  if vim.bo[buf].buftype ~= "terminal" then
    return nil
  end
  local hay = (api.nvim_buf_get_name(buf) .. " " .. (vim.b[buf].term_title or "") .. " " .. (vim.b[buf].term_name or ""))
  :lower()
  if hay:find("lazygit") then
    return "lazygit"
  elseif hay:find("claude") then
    return "claude"
  end
  return "terminal"
end

local function remark()
  local buf = api.nvim_get_current_buf()
  local tk = term_kind(buf)
  if tk == "lazygit" then
    return pick({
      "Veo que andas en lazygit. Cuidado con ese force-push.",
      "Commiteando, ¿eh? Que no se te escape nada.",
      "lazygit: donde los conflictos van a morir.",
      "Un buen stage vale más que mil disculpas.",
    })
  elseif tk == "claude" then
    return pick({
      "¿Charlando con Claude? Salúdalo de mi parte.",
      "Delegando en la IA, muy siglo XXI.",
      "Yo superviso mientras Claude teclea.",
      "Dos asistentes en pantalla; qué lujo.",
    })
  elseif tk == "terminal" then
    return pick({
      "Una terminal abierta. A teclear se ha dicho.",
      "Comandos van, comandos vienen.",
      "¿Compilando algo? Cruzo los dedos.",
      "Ojo con ese rm -rf, que yo miro.",
    })
  end
  local out = {
    "Deambular es mi cardio.",
    "No hago nada útil, pero te hago compañía.",
    "A veces solo quiero pasear por el buffer.",
    "Bonito tema el que tienes puesto.",
  }
  local function add(s)
    out[#out + 1] = s
  end
  local name = vim.fn.expand("%:t")
  local ft = vim.bo[buf].filetype
  local lines = api.nvim_buf_line_count(buf)
  local row = (api.nvim_win_get_cursor(0) or { 1 })[1]
  if vim.bo[buf].modified then
    add(("Tienes cambios sin guardar en %s. Solo lo menciono…"):format(name ~= "" and name or "este buffer"))
  end
  if name ~= "" then
    add(("Andas con %s, ya veo."):format(name))
  else
    add("Un buffer sin nombre; lienzo en blanco.")
  end
  if ft ~= "" then
    add(("Veo que escribes %s. Te queda bien."):format(ft))
  end
  if lines > 500 then
    add(("%d líneas… esto ya es un novelón."):format(lines))
  elseif lines <= 5 then
    add("Archivo cortito, se agradece.")
  end
  if row <= 1 then
    add("Arrancando desde arriba, clásico.")
  elseif row >= lines - 1 then
    add("Ya casi tocas el final del archivo.")
  else
    add(("Vas por la línea %d de %d."):format(row, lines))
  end
  local nd = 0
  pcall(function()
    nd = #vim.diagnostic.get(buf)
  end)
  if nd > 0 then
    add(("Cuento %d aviso%s del LSP por ahí. Tú sabrás."):format(nd, nd == 1 and "" or "s"))
  end
  local h = tonumber(os.date("%H")) or 12
  if h < 6 then
    add("¿Programando de madrugada? Yo también trasnocho.")
  elseif h < 12 then
    add("Buen día para escribir código.")
  elseif h < 20 then
    add("La tarde rinde, sigue así.")
  else
    add("Ya es de noche; no te desveles mucho.")
  end
  return out[math.random(#out)]
end

local function set_hl()
  local p = require("config.palette")
  api.nvim_set_hl(0, "ClippyMascot", { fg = p.fg, bg = "NONE", bold = true }) -- sin fondo: solo el carácter
  api.nvim_set_hl(0, "ClippyNormal", { fg = p.fg, bg = "NONE" })
  api.nvim_set_hl(0, "ClippyBorder", { fg = p.fg, bg = "NONE" })
end

-- ── Movimiento ──────────────────────────────────────────────────────
local function bounds()
  return math.max(1, vim.o.lines - MASCOT_H - 2), math.max(0, vim.o.columns - MASCOT_W - 1)
end
local function new_target()
  local mr, mc = bounds()
  target = { row = math.random(1, mr), col = math.random(0, mc) }
end
local function toward(a, b, s)
  if a < b then
    return math.min(a + s, b)
  elseif a > b then
    return math.max(a - s, b)
  end
  return a
end

-- Coloca el bocadillo pegado a la mascota (encima; debajo si no cabe).
local function place_bubble()
  if not (b_win and api.nvim_win_is_valid(b_win)) then return end
  local h = api.nvim_win_get_height(b_win) + 2
  local w = api.nvim_win_get_width(b_win) + 2
  local row = pos.row - h - 1  -- intentar arriba
  local above = row >= 0
  if not above then row = pos.row + MASCOT_H + 1 end -- +1: deja la fila de la cola
  local col = math.min(pos.col, math.max(0, vim.o.columns - w))
  pcall(api.nvim_win_set_config, b_win, { relative = "editor", row = row, col = col })

  -- cola: una fila entre bocadillo y mascota
  if t_win and api.nvim_win_is_valid(t_win) then
    local tail = above and "╰─╮" or "╭─╯"
    -- centrar la cola horizontalmente sobre la mascota
    local tail_col = pos.col + math.floor(MASCOT_W / 2) - 1
    local tail_row = above and (row + h) or (pos.row + MASCOT_H) -- fila libre entre mascota y bocadillo
    vim.bo[t_buf].modifiable = true
    api.nvim_buf_set_lines(t_buf, 0, -1, false, { tail })
    vim.bo[t_buf].modifiable = false
    pcall(api.nvim_win_set_config, t_win, {
      relative = "editor",
      row = tail_row,
      col = tail_col,
    })
  end
end

-- El movimiento y la pausa se turnan el mismo timer: mientras camina va en modo
-- repetido (STEP_MS); al llegar, se para y arranca un disparo único que dura la pausa
-- y luego vuelve a caminar. Así, quieto, no gasta CPU (nada de despertar 100 veces/s).
local step, start_moving, rest_then_wander

function start_moving()
  if not move_timer then
    move_timer = vim.uv.new_timer()
  end
  move_timer:stop()
  move_timer:start(STEP_MS, STEP_MS, vim.schedule_wrap(step))
end

function rest_then_wander(ms)
  if not move_timer then
    move_timer = vim.uv.new_timer()
  end
  move_timer:stop()
  move_timer:start(ms, 0, vim.schedule_wrap(function()
    if not enabled then
      return
    end
    new_target()
    start_moving()
  end))
end

function step()
  if not (enabled and m_win and api.nvim_win_is_valid(m_win)) then
    return
  end
  if dragging then
    return -- mientras se arrastra con el mouse, no deambula
  end
  local nr = toward(pos.row, target.row, 1)
  local nc = toward(pos.col, target.col, 1)
  if nr == pos.row and nc == pos.col then
    rest_then_wander(math.random(PAUSE_MIN, PAUSE_MAX)) -- descanso al llegar
    return
  end
  pos.row, pos.col = nr, nc
  pcall(api.nvim_win_set_config, m_win, { relative = "editor", row = pos.row, col = pos.col })
  place_bubble()
end

-- ── Arrastre con el mouse ───────────────────────────────────────────
local MOUSE_MODES = { "n", "i", "v", "t" }

-- La mascota es relativa a la rejilla "editor", que incluye la tabline: su fila 0 es
-- la fila 1 de pantalla. Por eso screenrow (1-based) - 1 == fila del editor, sin ajustes.

local function feed_native(key)
  api.nvim_feedkeys(api.nvim_replace_termcodes(key, true, false, true), "n", false)
end

local function on_press()
  if enabled and m_win and api.nvim_win_is_valid(m_win) then
    local mp = vim.fn.getmousepos()
    local er = mp.screenrow - 1
    local ec = mp.screencol - 1
    if er >= pos.row and er < pos.row + MASCOT_H and ec >= pos.col and ec < pos.col + MASCOT_W then
      dragging = true
      drag_off = { row = er - pos.row, col = ec - pos.col }
      return
    end
  end
  feed_native("<LeftMouse>")
end

local function on_drag()
  if enabled and dragging then
    local mp = vim.fn.getmousepos()
    local mr, mc = bounds()
    pos.row = math.max(0, math.min(mp.screenrow - 1 - drag_off.row, mr))
    pos.col = math.max(0, math.min(mp.screencol - 1 - drag_off.col, mc))
    if m_win and api.nvim_win_is_valid(m_win) then
      pcall(api.nvim_win_set_config, m_win, { relative = "editor", row = pos.row, col = pos.col })
    end
    place_bubble()
    return
  end
  feed_native("<LeftDrag>")
end

local function on_release()
  if dragging then
    dragging = false
    new_target() -- retoma el deambular desde donde quedó
    start_moving()
    return
  end
  feed_native("<LeftRelease>")
end

local function set_mouse_maps()
  vim.keymap.set(MOUSE_MODES, "<LeftMouse>", on_press, { desc = "Clippy: arrastrar" })
  vim.keymap.set(MOUSE_MODES, "<LeftDrag>", on_drag, {})
  vim.keymap.set(MOUSE_MODES, "<LeftRelease>", on_release, {})
end

local function del_mouse_maps()
  for _, k in ipairs({ "<LeftMouse>", "<LeftDrag>", "<LeftRelease>" }) do
    pcall(vim.keymap.del, MOUSE_MODES, k)
  end
end

-- ── Ventanas ────────────────────────────────────────────────────────
local function open_mascot()
  if m_win and api.nvim_win_is_valid(m_win) then
    return
  end
  if not (m_buf and api.nvim_buf_is_valid(m_buf)) then
    m_buf = api.nvim_create_buf(false, true)
    vim.bo[m_buf].bufhidden = "hide"
    vim.bo[m_buf].filetype = "clippy"
    api.nvim_buf_set_lines(m_buf, 0, -1, false, MASCOT)
  end
  m_win = api.nvim_open_win(m_buf, false, {
    relative = "editor",
    row = pos.row,
    col = pos.col,
    width = MASCOT_W,
    height = MASCOT_H,
    style = "minimal",
    border = "none", -- sin marco: solo el carácter
    focusable = false,
    zindex = Z,
    noautocmd = true,
  })
  vim.w[m_win].borderless = true
  require("plugins.local.ui.win").set_opts(m_win, { winhighlight = "Normal:ClippyMascot,EndOfBuffer:ClippyMascot" })
end

local function close_bubble()
  if b_win and api.nvim_win_is_valid(b_win) then
    pcall(api.nvim_win_close, b_win, true)
  end
  if t_win and api.nvim_win_is_valid(t_win) then
    pcall(api.nvim_win_close, t_win, true)
  end
  b_win = nil
  t_win = nil
end

local function close_all()
  close_bubble()
  if m_win and api.nvim_win_is_valid(m_win) then
    pcall(api.nvim_win_close, m_win, true)
  end
  m_win = nil
end

local function wrap(msg, w)
  local lines, line = {}, ""
  for word in msg:gmatch("%S+") do
    if #line > 0 and #line + #word + 1 > w then
      lines[#lines + 1] = line
      line = word
    else
      line = (line == "") and word or (line .. " " .. word)
    end
  end
  if line ~= "" then
    lines[#lines + 1] = line
  end
  return lines
end

-- Clippy dice `msg`: muestra el bocadillo junto a la mascota y programa su auto-ocultado.
function M.say(msg)
  if not enabled then
    return
  end
  local lines = {}
  for i, l in ipairs(wrap(msg, BUBBLE_W - 4)) do
    lines[i] = " " .. l .. " "
  end
  if not (b_buf and api.nvim_buf_is_valid(b_buf)) then
    b_buf = api.nvim_create_buf(false, true)
    vim.bo[b_buf].bufhidden = "hide"
    vim.bo[b_buf].filetype = "clippy"
  end
  vim.bo[b_buf].modifiable = true
  api.nvim_buf_set_lines(b_buf, 0, -1, false, lines)
  vim.bo[b_buf].modifiable = false
  if not (b_win and api.nvim_win_is_valid(b_win)) then
    b_win = api.nvim_open_win(b_buf, false, {
      relative = "editor",
      row = 0,
      col = 0,
      width = BUBBLE_W,
      height = #lines,
      style = "minimal",
      border = "rounded",
      focusable = false,
      zindex = Z + 1, -- por encima de la mascota
      noautocmd = true,
    })
    require("plugins.local.ui.win").set_opts(b_win, {
      winhighlight = "Normal:ClippyNormal,FloatBorder:ClippyBorder,EndOfBuffer:ClippyNormal",
      wrap = false,
    })
  else
    pcall(api.nvim_win_set_config, b_win, { width = BUBBLE_W, height = #lines })
  end

  -- cola del bocadillo
  if not (t_buf and api.nvim_buf_is_valid(t_buf)) then
    t_buf = api.nvim_create_buf(false, true)
    vim.bo[t_buf].bufhidden = "hide"
    vim.bo[t_buf].filetype = "clippy"
  end
  if not (t_win and api.nvim_win_is_valid(t_win)) then
    t_win = api.nvim_open_win(t_buf, false, {
      relative = "editor",
      row = 0, col = 0,
      width = 3,
      height = 1,
      style = "minimal",
      border = "none",
      focusable = false,
      zindex = Z + 1,
      noautocmd = true,
    })
    require("plugins.local.ui.win").set_opts(t_win, {
      winhighlight = "Normal:ClippyBorder,EndOfBuffer:ClippyBorder",
    })
  end

  place_bubble()

  if not hide_timer then
    hide_timer = vim.uv.new_timer()
  end
  hide_timer:stop()
  hide_timer:start(SHOW_MS, 0, vim.schedule_wrap(close_bubble))
end

-- ── Reacciones ──────────────────────────────────────────────────────
local did_autocmds = false
local function ensure_autocmds()
  if did_autocmds then
    return
  end
  did_autocmds = true
  require("config.theme").register(set_hl)
  local grp = api.nvim_create_augroup("Clippy", { clear = true })
  api.nvim_create_autocmd("BufWritePost", {
    group = grp,
    callback = function()
      if enabled then
        M.say(pick(PRAISE))
      end
    end,
  })
  api.nvim_create_autocmd("DiagnosticChanged", {
    group = grp,
    callback = function(a)
      if not enabled then
        return
      end
      local n = #vim.diagnostic.get(a.buf, { severity = vim.diagnostic.severity.ERROR })
      if n > 0 then
        M.say(("Veo %d error%s. ¿Los revisamos?"):format(n, n == 1 and "" or "es"))
      end
    end,
  })
  api.nvim_create_autocmd("CursorHold", {
    group = grp,
    callback = function()
      if enabled and (os.time() - last_tip) > TIP_GAP then
        last_tip = os.time()
        M.say(remark())
      end
    end,
  })
  -- Acciones de workspace (crear, cambiar, renombrar, reordenar): las emite workspace.lua
  api.nvim_create_autocmd("User", {
    group = grp,
    pattern = { "WorkspaceNew", "WorkspaceRenamed", "WorkspaceSwitch", "WorkspaceMoved" },
    callback = function(a)
      if not enabled then
        return
      end
      local lines = WS_LINES[a.match]
      if lines then
        local name = (a.data and a.data.name) or "el workspace"
        M.say(pick(lines):format(name))
      end
    end,
  })
  api.nvim_create_autocmd("VimResized", {
    group = grp,
    callback = function()
      if enabled and m_win and api.nvim_win_is_valid(m_win) then
        local mr, mc = bounds()
        pos.row, pos.col = math.min(pos.row, mr), math.min(pos.col, mc)
        pcall(api.nvim_win_set_config, m_win, { relative = "editor", row = pos.row, col = pos.col })
        place_bubble()
      end
    end,
  })
  -- Cuando se abre una terminal
  api.nvim_create_autocmd("TermEnter", {
    group = grp,
    callback = function()
      if enabled and (os.time() - last_tip) > TIP_GAP and math.random(0, 3) == 0 then
        last_tip = os.time()
        M.say(remark())
      end
    end,
  })
  -- Global entre workspaces: los flotantes son por-tab, así que al cambiar de tab se reabre
  -- la mascota en la actual (cerrando la de la anterior) para que siga presente.
  api.nvim_create_autocmd("TabEnter", {
    group = grp,
    callback = function()
      if not enabled then
        return
      end
      close_bubble()
      if m_win and api.nvim_win_is_valid(m_win) then
        pcall(api.nvim_win_close, m_win, true)
      end
      m_win = nil
      open_mascot() -- en la tab actual, conservando la posición
    end,
  })
end

-- Cierra ventanas/buffers de Clippy que quedaron de una recarga previa (:ReloadConfig
-- reinicia el estado del módulo pero deja vivas las ventanas viejas). Los buffers llevan
-- filetype "clippy"; borrarlos con force cierra también sus ventanas en cualquier tab.
local function close_orphans()
  for _, tp in ipairs(api.nvim_list_tabpages()) do
    for _, w in ipairs(api.nvim_tabpage_list_wins(tp)) do
      if w ~= m_win and w ~= b_win and api.nvim_win_is_valid(w) and vim.bo[api.nvim_win_get_buf(w)].filetype == "clippy" then
        pcall(api.nvim_win_close, w, true)
      end
    end
  end
  for _, b in ipairs(api.nvim_list_bufs()) do
    if b ~= m_buf and b ~= b_buf and api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "clippy" then
      pcall(api.nvim_buf_delete, b, { force = true })
    end
  end
end

-- ── API pública ────────────────────────────────────────────────────
function M.setup()
  close_orphans()
end

function M.toggle()
  ensure_autocmds()
  enabled = not enabled
  if enabled then
    pos = { row = math.floor(vim.o.lines / 2), col = math.floor(vim.o.columns / 2) }
    new_target()
    open_mascot()
    start_moving()
    set_mouse_maps()
    M.say(GREET)
  else
    dragging = false
    del_mouse_maps()
    if move_timer then
      move_timer:stop()
    end
    if hide_timer then
      hide_timer:stop()
    end
    close_all()
  end
  vim.notify(
    enabled and "Clippy activado" or "Clippy desactivado",
    vim.log.levels.INFO,
    { title = "Clippy", ephemeral = true }
  )
end

function M.tip()
  if not enabled then
    M.toggle()
    return
  end
  last_tip = os.time()
  M.say(remark())
end

return M
