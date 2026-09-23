-- Clippy: mascota-asistente (plugin-free) que DEAMBULA por la pantalla, siempre por encima
-- de todo, y suelta un globo de diálogo al reaccionar (errores del LSP, guardar, tips al
-- estar inactivo). Off por defecto; <leader>pp lo alterna, <leader>pt suelta un tip.
local api = vim.api
local M = {}

-- Cara de la mascota (4 celdas de ancho, 4 de alto). Filas superior/inferior fijas; se
-- animan los ojos (fila 2) y la boca (fila 3). Los ojos dependen de la EXPRESIÓN: redondos
-- en reposo/hablando, y medias lunas apuntando hacia donde camina (izq/der/arriba/abajo).
-- Nota: ◐◑◒◓● son de "ancho ambiguo"; deberían verse a 1 celda, si no, hay que cambiarlos.
local TOP, BOT = "╭─╮ ", "╰──╯"
local MOUTH_SMILE, MOUTH_OPEN = "│╰╯│", "│╰╯│"
local EYE = {
  idle = "●", -- reposo: ojo redondo
  talk = "●", -- hablando: igual (protagoniza la boca)
  left = "◐", -- media luna: mira a la izquierda
  right = "◑", -- ...a la derecha
  up = "◓", -- ...arriba
  down = "◒", -- ...abajo
}
local BLINK = "─" -- parpadeo (párpado cerrado)
-- Fila de ojos: dos ojos separados (col 1 y 3) + borde derecho.
local function eye_row(ch)
  return ch .. " " .. ch .. "╭"
end
local MASCOT = { TOP, eye_row("●"), MOUTH_SMILE, BOT } -- cara base (tamaño y relleno inicial)
local MASCOT_W = 4                       -- ancho en celdas
local MASCOT_H = #MASCOT                 -- alto (nº de filas)
local ANIM_MS = 280                      -- ms entre frames de animación
local Z = 250                            -- zindex: por encima de splits y flotantes normales
local STEP_MS = 10                       -- ms entre pasos mientras se mueve (menor = más rápido)
local PAUSE_MIN, PAUSE_MAX = 5000, 10000 -- ms quieto al llegar a un destino (sin gastar CPU)
local BUBBLE_W = 42
local SHOW_MS = 3000                   -- cuánto queda visible el bocadillo
local TIP_GAP = 30                     -- segundos mínimos entre tips por inactividad

local m_win, m_buf                     -- mascota
local b_win, b_buf                     -- bocadillo
local t_win, t_buf                     -- cola del bocadillo
local move_timer, hide_timer, anim_timer
local anim_frame, anim_state = 1, "idle"
local enabled = false
local last_tip = 0
local pos = { row = 5, col = 5 }
local target = { row = 5, col = 5 }
local origin = { row = 5, col = 5 } -- punto de partida del trayecto actual
local t = 1 -- progreso 0→1 del trayecto
local t_step = 0.04 -- avance de t por tick = velocidad (aleatoria por trayecto)
local curve_amp = 0 -- amplitud del arco lateral (aleatoria, con signo)
local perp = { r = 0, c = 0 } -- vector unitario perpendicular al trayecto
local dragging = false
local drag_off = { row = 0, col = 0 }

local GREET = "¡Hola! Soy Clippy, tu asistente. Andaré por aquí."
local PRAISE = { "¡Guardado! 💾", "Buen trabajo, sigue así ✨", "Todo en orden." }
local FLEE = {
  "¡Uy, perdón! Te dejo trabajar.",
  "Me quito de en medio.",
  "¡Ahí voy, que no te tapo!",
  "Perdona, no quería estorbar.",
  "Mejor me corro para allá.",
  "¡Todo tuyo el código!",
}
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

-- Nivel de charla (configurable): probabilidad de comentar una acción. "callado" = 0 (solo
-- mascota, sin frases). Se lee de settings en cada evento para reflejar cambios en caliente.
local CHATTER = { callado = 0, poco = 0.15, normal = 0.34, hablador = 0.7 }
local function chatter_p()
  return CHATTER[require("config.settings").value("ui.clippy_chatter", "normal")] or 0.34
end
local function talk_ok()
  return math.random() < chatter_p()
end

-- Velocidad (configurable): rango de avance de t por tick (mayor = más rápido).
local SPEED = {
  lento = { 0.0015, 0.0025 },
  normal = { 0.006, 0.008 },
  rapido = { 0.02, 0.03 },
}
local function speed_step()
  local s = SPEED[require("config.settings").value("ui.clippy_speed", "lento")] or SPEED.lento
  return s[1] + math.random() * s[2]
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
    add(("Veo que escribes %s. Observando..."):format(ft))
  end
  if lines > 500 then
    add(("%d líneas… esto ... spaguetti?."):format(lines))
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

-- Cursor en coordenadas del editor (misma rejilla que la mascota). nil si no se puede leer.
local function cursor_ec()
  local ok_r, sr = pcall(vim.fn.screenrow)
  local ok_c, sc = pcall(vim.fn.screencol)
  if not (ok_r and ok_c) or sr < 1 or sc < 1 then
    return nil
  end
  return sr - 1, sc - 1
end

-- Distancia² del centro de la mascota (en r,c) al cursor. Las filas pesan el doble: compartir
-- fila con el cursor tapa la línea actual, molesta más que compartir columna.
local function dist2_cursor(r, c, cr, cc)
  local dr = (r + MASCOT_H / 2) - cr
  local dc = (c + MASCOT_W / 2) - cc
  return (dr * 2) ^ 2 + dc ^ 2
end

-- ¿El cursor está dentro del "espacio personal" de la mascota (con margen)?
local function cursor_near()
  local cr, cc = cursor_ec()
  if not cr then
    return false
  end
  return cr >= pos.row - 1 and cr <= pos.row + MASCOT_H and cc >= pos.col - 4 and cc <= pos.col + MASCOT_W + 4
end

-- Columnas (rejilla del editor) que ocupan los paneles fijos de la tab actual: sidebar,
-- explorador, minimapa, etc. Son franjas verticales, así que basta el rango de columnas.
local PANEL_FTS = {
  explorer = true,
  netrw = true,
  settings = true,
  mason = true,
  minimap = true,
  sidebar = true,
}
local function panel_cols()
  local out = {}
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_config(w).relative == "" and PANEL_FTS[vim.bo[api.nvim_win_get_buf(w)].filetype] then
      local wc = api.nvim_win_get_position(w)[2]
      out[#out + 1] = { wc, wc + api.nvim_win_get_width(w) - 1 }
    end
  end
  return out
end

-- ¿La mascota (o un candidato) en la columna `c` se solapa con algún panel?
local function on_panel(c, panels)
  local c2 = c + MASCOT_W - 1
  for _, iv in ipairs(panels) do
    if not (c2 < iv[1] or c > iv[2]) then
      return true
    end
  end
  return false
end
local function over_panel()
  return on_panel(pos.col, panel_cols())
end

-- Elige un punto (fila, col) lejos del cursor y fuera de los paneles: prueba varios
-- candidatos y se queda con el mejor válido (o el más lejano si todos caen en un panel).
local function pick_spot()
  local mr, mc = bounds()
  local cr, cc = cursor_ec()
  local panels = panel_cols()
  local best, best_any
  for _ = 1, 16 do
    local r, c = math.random(1, mr), math.random(0, mc)
    local d = cr and dist2_cursor(r, c, cr, cc) or 0
    if not best_any or d > best_any.d then
      best_any = { row = r, col = c, d = d }
    end
    if not on_panel(c, panels) and (not best or d > best.d) then
      best = { row = r, col = c, d = d }
    end
  end
  return best or best_any
end

-- Punto de arranque: lejos del cursor y fuera de los paneles.
local function far_start()
  return pick_spot()
end

local function new_target()
  origin = { row = pos.row, col = pos.col }
  target = pick_spot()
  t = 0
  t_step = speed_step() -- velocidad aleatoria dentro del nivel configurado
  local dr, dc = target.row - origin.row, target.col - origin.col
  local len = math.sqrt(dr * dr + dc * dc)
  perp = len > 0 and { r = -dc / len, c = dr / len } or { r = 0, c = 0 }
  curve_amp = (math.random() * 2 - 1) * math.min(8, len * 0.35) -- arco lateral (±), según distancia
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
  t = t + t_step
  if t >= 1 then
    pos.row, pos.col = target.row, target.col
    pcall(api.nvim_win_set_config, m_win, { relative = "editor", row = pos.row, col = pos.col })
    place_bubble()
    rest_then_wander(math.random(PAUSE_MIN, PAUSE_MAX)) -- descanso al llegar
    return
  end
  -- recta origen→destino + desvío lateral con sin (0 en extremos, máx en el medio) = arco
  local off = math.sin(t * math.pi) * curve_amp
  local br = origin.row + (target.row - origin.row) * t + perp.r * off
  local bc = origin.col + (target.col - origin.col) * t + perp.c * off
  local mr, mc = bounds()
  pos.row = math.max(0, math.min(math.floor(br + 0.5), mr))
  pos.col = math.max(0, math.min(math.floor(bc + 0.5), mc))
  pcall(api.nvim_win_set_config, m_win, { relative = "editor", row = pos.row, col = pos.col })
  place_bubble()
end

-- ── Animación del personaje ─────────────────────────────────────────
-- Estado según lo que hace: hablando (hay bocadillo) > moviéndose (trayecto en curso) > quieto.
local function cur_state()
  if b_win and api.nvim_win_is_valid(b_win) then
    return "talking"
  elseif dragging or t < 1 then
    return "moving"
  end
  return "idle"
end

-- Hacia dónde camina, según el vector del trayecto (origen→destino): el eje dominante decide
-- izquierda/derecha o arriba/abajo (las medias lunas sí pueden mirar en las cuatro).
local function move_dir()
  local dc, dr = target.col - origin.col, target.row - origin.row
  if math.abs(dc) >= math.abs(dr) then
    return dc >= 0 and "right" or "left"
  end
  return dr >= 0 and "down" or "up"
end

-- Parpadeo natural: ojos abiertos casi siempre y un cierre breve (un tick) cada tantos
-- ticks aleatorios, en vez de abrir/cerrar a ritmo fijo.
local blink_in, blink_left = math.random(6, 20), 0
local function eyes_closed()
  if blink_left > 0 then
    blink_left = blink_left - 1
    return true
  end
  blink_in = blink_in - 1
  if blink_in <= 0 then
    blink_in = math.random(6, 22) -- ~1.7 a ~6 s hasta el próximo parpadeo
    blink_left = (math.random() < 0.15) and 1 or 0 -- de vez en cuando, doble parpadeo
    return true
  end
  return false
end

-- Expresiones emocionales transitorias por evento (independientes de si habla o no):
-- feliz al guardar, preocupado con errores. El sueño se deduce de la inactividad.
local MOOD = {
  happy = { eye = "^", mouth = MOUTH_SMILE }, -- ojos contentos ^^
  worried = { eye = "◉", mouth = "│╭╮│" }, -- ojos muy abiertos + boca hacia abajo
}
local mood, mood_until = nil, 0
local last_activity = os.time()
local SLEEP_AFTER = 90 -- s sin actividad (y quieto) para quedarse dormido
local function set_mood(name, secs)
  mood, mood_until = name, os.time() + (secs or 3)
end

-- Un tick de animación: compone la cara del estado/expresión actual y la pinta.
local function anim_tick()
  if not (enabled and m_buf and api.nvim_buf_is_valid(m_buf)) then
    return
  end
  local s = cur_state()
  local now = os.time()
  local m = (mood and now < mood_until) and MOOD[mood] or nil
  local top, eye, mouth = TOP, nil, nil

  -- boca: si habla, alterna abierta/cerrada (así se ve "hablando")
  if s == "talking" then
    anim_frame = (s ~= anim_state) and 1 or ((anim_frame == 1) and 2 or 1)
    mouth = (anim_frame == 1) and MOUTH_OPEN or MOUTH_SMILE
  end

  if m then -- expresión emocional: manda en los ojos (y en la boca si no habla)
    eye = m.eye
    mouth = mouth or m.mouth
  elseif s == "idle" and (now - last_activity) > SLEEP_AFTER then -- dormido: ojos cerrados + z
    anim_frame = (s ~= anim_state) and 1 or ((anim_frame == 1) and 2 or 1)
    top = (anim_frame == 1) and "╭─╮z" or "╭─╮Z"
    eye, mouth = "─", "│╰╯│"
  else -- normal: ojos por dirección/reposo con parpadeo natural
    eye = (s == "moving") and EYE[move_dir()] or EYE.idle
    if eyes_closed() then
      eye = BLINK
    end
  end

  anim_state = s
  api.nvim_buf_set_lines(m_buf, 0, -1, false, { top, eye_row(eye), mouth or MOUTH_SMILE, BOT })
end

local function start_anim()
  if not anim_timer then
    anim_timer = vim.uv.new_timer()
  end
  anim_timer:stop()
  anim_timer:start(ANIM_MS, ANIM_MS, vim.schedule_wrap(anim_tick))
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
      if not enabled then
        return
      end
      set_mood("happy", 3) -- cara feliz (aunque esté callado)
      if talk_ok() then
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
        set_mood("worried", 4) -- cara preocupada (aunque esté callado)
        if talk_ok() then
          M.say(("Veo %d error%s. ¿Los revisamos?"):format(n, n == 1 and "" or "es"))
        end
      end
    end,
  })
  api.nvim_create_autocmd("CursorHold", {
    group = grp,
    callback = function()
      if enabled and (os.time() - last_tip) > TIP_GAP and talk_ok() then
        last_tip = os.time()
        M.say(remark())
      end
    end,
  })
  -- Que no moleste: si el cursor se le acerca (o queda sobre un panel) estando quieto, se aparta.
  api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = grp,
    callback = function()
      last_activity = os.time() -- para saber cuándo se queda dormido
      if enabled and not dragging and t >= 1 and (cursor_near() or over_panel()) then
        new_target() -- elige un destino lejos del cursor
        start_moving()
        if (os.time() - last_tip) > TIP_GAP and talk_ok() then
          last_tip = os.time() -- a veces avisa que se aparta (sin volverse pesado)
          M.say(pick(FLEE))
        end
      end
    end,
  })
  -- Acciones de workspace (crear, cambiar, renombrar, reordenar): las emite workspace.lua
  api.nvim_create_autocmd("User", {
    group = grp,
    pattern = { "WorkspaceNew", "WorkspaceRenamed", "WorkspaceSwitch", "WorkspaceMoved" },
    callback = function(a)
      if not enabled or not talk_ok() then
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
      if enabled and (os.time() - last_tip) > TIP_GAP and talk_ok() then
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
local function do_enable(greet)
  pos = far_start() -- aparecer lejos del cursor
  new_target()
  open_mascot()
  start_moving()
  start_anim()
  set_mouse_maps()
  if greet and chatter_p() > 0 then
    M.say(GREET)
  end
end

local function do_disable()
  dragging = false
  del_mouse_maps()
  for _, tm in ipairs({ move_timer, hide_timer, anim_timer }) do
    if tm then
      tm:stop()
    end
  end
  close_all()
end

-- Activa/desactiva y lo persiste en settings (ui.clippy). `silent` omite el saludo (al
-- restaurar en el arranque) y la notificación.
function M.set_enabled(v, silent)
  ensure_autocmds()
  v = v and true or false
  if v == enabled then
    return
  end
  enabled = v
  require("config.settings").record("ui.clippy", enabled, false)
  if enabled then
    do_enable(not silent)
  else
    do_disable()
  end
end

function M.is_enabled()
  return enabled
end

-- Nivel de charla y velocidad: get lee de settings, set persiste. Surten efecto en el
-- próximo evento/trayecto, así que no hay preview aparte.
function M.get_chatter()
  return require("config.settings").value("ui.clippy_chatter", "normal")
end
function M.set_chatter(v)
  require("config.settings").record("ui.clippy_chatter", v, "normal")
end
function M.get_speed()
  return require("config.settings").value("ui.clippy_speed", "lento")
end
function M.set_speed(v)
  require("config.settings").record("ui.clippy_speed", v, "lento")
end

function M.toggle()
  M.set_enabled(not enabled)
  vim.notify(
    enabled and "Clippy activado" or "Clippy desactivado",
    vim.log.levels.INFO,
    { title = "Clippy", ephemeral = true }
  )
end

-- Arranque / :ReloadConfig: limpiar cualquier Clippy huérfano y, si quedó activado, restaurarlo.
function M.setup()
  close_orphans()
  if require("config.settings").value("ui.clippy", false) then
    vim.schedule(function()
      M.set_enabled(true, true)
    end)
  end
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
