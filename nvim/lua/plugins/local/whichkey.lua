local api = vim.api
local M = {}

-- Retardo antes de mostrar el popup en niveles ANIDADOS: usamos el mismo
-- 'timeoutlen' de Vim que rige el primer nivel, para un solo botón coherente.
-- (El primer nivel es inmediato porque Vim ya esperó 'timeoutlen' antes de M.show.)
local function delay()
  return vim.o.timeoutlen
end

-- ── Descripciones curadas de prefijos integrados ───────────────────
-- Por prefijo (en bytes crudos) -> lista de { raw = <secuencia completa>, desc }
local BUILTIN = {}

local function add_builtin(prefix_keys, list)
  local praw = api.nvim_replace_termcodes(prefix_keys, true, true, true)
  local entries = {}
  for _, e in ipairs(list) do
    entries[#entries + 1] = {
      raw = api.nvim_replace_termcodes(e[1], true, true, true),
      desc = e[2],
    }
  end
  BUILTIN[praw] = entries
end

add_builtin("g", {
  { "gg", "Ir al inicio del archivo" },
  { "gv", "Reseleccionar última selección" },
  { "gi", "Insertar en la última posición" },
  { "gI", "Insertar en la columna 1" },
  { "gJ", "Unir líneas sin espacio" },
  { "gp", "Pegar y mover el cursor al final" },
  { "gP", "Pegar antes y mover el cursor" },
  { "gf", "Abrir el archivo bajo el cursor" },
  { "gx", "Abrir URL/archivo con la app del sistema" },
  { "ga", "Mostrar el código del carácter" },
  { "g;", "Ir al cambio anterior" },
  { "g,", "Ir al cambio siguiente" },
  { "g_", "Último carácter no-blanco" },
  { "gj", "Bajar una línea visual" },
  { "gk", "Subir una línea visual" },
  { "gu", "Pasar a minúsculas (operador)" },
  { "gU", "Pasar a mayúsculas (operador)" },
  { "g~", "Invertir mayúsculas (operador)" },
  { "gq", "Reformatear texto (operador)" },
})

add_builtin("z", {
  { "zz", "Centrar la línea actual" },
  { "zt", "Línea actual arriba" },
  { "zb", "Línea actual abajo" },
  { "za", "Alternar fold" },
  { "zo", "Abrir fold" },
  { "zc", "Cerrar fold" },
  { "zR", "Abrir todos los folds" },
  { "zM", "Cerrar todos los folds" },
  { "zf", "Crear fold (operador)" },
  { "zd", "Borrar fold" },
  { "z=", "Sugerencias de ortografía" },
})

add_builtin("<C-w>", {
  { "<C-w>w", "Ciclar a la siguiente ventana" },
  { "<C-w>p", "Ventana anterior" },
  { "<C-w>h", "Ventana de la izquierda" },
  { "<C-w>j", "Ventana de abajo" },
  { "<C-w>k", "Ventana de arriba" },
  { "<C-w>l", "Ventana de la derecha" },
  { "<C-w>s", "Split horizontal" },
  { "<C-w>v", "Split vertical" },
  { "<C-w>q", "Cerrar ventana" },
  { "<C-w>o", "Cerrar las demás ventanas" },
  { "<C-w>=", "Igualar tamaños" },
  { "<C-w>x", "Intercambiar ventana" },
  { "<C-w>r", "Rotar ventanas" },
  { "<C-w>T", "Mover la ventana a una tab nueva" },
})

-- ── Utilidades ─────────────────────────────────────────────────────
local function rawof(m)
  return m.lhsraw or api.nvim_replace_termcodes(m.lhs, true, true, true)
end

-- Candidatos (mapeos de usuario + integrados curados) que empiezan con `seq`
local function candidates(seq, builtin_list)
  local res = {}
  local function add_user(maps)
    for _, m in ipairs(maps) do
      local raw = rawof(m)
      if raw and #raw >= #seq and raw:sub(1, #seq) == seq then
        res[#res + 1] = { raw = raw, desc = m.desc, mapping = m }
      end
    end
  end
  add_user(api.nvim_get_keymap("n"))
  add_user(api.nvim_buf_get_keymap(0, "n"))
  if builtin_list then
    for _, e in ipairs(builtin_list) do
      if #e.raw >= #seq and e.raw:sub(1, #seq) == seq then
        res[#res + 1] = { raw = e.raw, desc = e.desc, builtin = true }
      end
    end
  end
  return res
end

-- Agrupa por la siguiente tecla tras `seq`
local function build_entries(seq, longer)
  local groups = {}
  for _, c in ipairs(longer) do
    local rest = c.raw:sub(#seq + 1)
    local ch = rest:sub(1, 1)
    local g = groups[ch]
    if not g then
      g = { count = 0 }
      groups[ch] = g
    end
    g.count = g.count + 1
    if #rest == 1 then
      g.leaf = c
    end
  end

  local entries = {}
  for ch, g in pairs(groups) do
    local label
    if g.leaf and g.count == 1 then
      label = g.leaf.desc or "?"
    else
      label = "\u{f0770} +" .. g.count
    end
    entries[#entries + 1] = { key = ch, label = label }
  end
  table.sort(entries, function(a, b)
    return a.key < b.key
  end)
  return entries
end

-- ── Popup ──────────────────────────────────────────────────────────
local popup_win, popup_buf

local function close_popup()
  if popup_win and api.nvim_win_is_valid(popup_win) then
    api.nvim_win_close(popup_win, true)
  end
  if popup_buf and api.nvim_buf_is_valid(popup_buf) then
    api.nvim_buf_delete(popup_buf, { force = true })
  end
  popup_win, popup_buf = nil, nil
end

local function open_popup(seq, entries)
  local lines, width = {}, 1
  for _, e in ipairs(entries) do
    local line = string.format("  %s  %s", vim.fn.keytrans(e.key), e.label)
    lines[#lines + 1] = line
    width = math.max(width, vim.fn.strdisplaywidth(line) + 2)
  end

  popup_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(popup_buf, 0, -1, false, lines)
  vim.bo[popup_buf].modifiable = false

  popup_win = api.nvim_open_win(popup_buf, false, {
    relative = "editor",
    anchor = "SW",
    row = vim.o.lines - 5,
    col = (vim.o.columns - width) / 2,
    width = math.min(width, vim.o.columns),
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = " " .. vim.fn.keytrans(seq) .. " ",
    title_pos = "left",
    focusable = false,
    noautocmd = true,
  })
end

-- Bloquea esperando la tecla con el popup ya abierto. Devuelve la tecla o nil.
local function block_for_key(seq, entries)
  open_popup(seq, entries)
  vim.cmd("redraw")
  local ok, ch = pcall(vim.fn.getcharstr)
  close_popup()
  return ok and ch or nil
end

-- Lee la siguiente tecla. Si ya hay una en el typeahead (tecleaste rápido), la
-- usa sin mostrar nada.
-- `immediate` (primer nivel): Vim ya esperó `timeoutlen` antes de invocarnos, así
-- que la pausa ya ocurrió -> mostrar el popup de inmediato.
-- Niveles siguientes: programar el popup tras DELAY ms y bloquear en getcharstr();
-- si pulsas antes, getcharstr() devuelve ya y el timer se cancela (sin popup).
local function read_key(seq, entries, immediate)
  -- ¿tecla ya pendiente? -> úsala directamente, sin delay ni popup
  local c = vim.fn.getchar(0)
  if c ~= 0 then
    return (type(c) == "number") and vim.fn.nr2char(c) or c
  end

  if immediate then
    return block_for_key(seq, entries)
  end

  -- programar la aparición del popup tras 'timeoutlen' ms (cosmético; no bloquea)
  local timer = vim.uv.new_timer()
  timer:start(
    delay(),
    0,
    vim.schedule_wrap(function()
      open_popup(seq, entries)
      vim.cmd("redraw")
    end)
  )

  -- bloquear hasta que haya una tecla (el timer corre en paralelo)
  local ok, ch = pcall(vim.fn.getcharstr)

  if not timer:is_closing() then
    timer:stop()
    timer:close()
  end
  close_popup()
  return ok and ch or nil
end

-- Ejecuta un mapeo de usuario (callback directo o feed del rhs)
local function execute(m)
  vim.schedule(function()
    if m.callback then
      m.callback()
    elseif m.rhs and m.rhs ~= "" then
      local keys = api.nvim_replace_termcodes(m.rhs, true, true, true)
      api.nvim_feedkeys(keys, m.noremap == 1 and "n" or "m", false)
    end
  end)
end

-- Reenvía las teclas crudas a Vim (comando integrado), conservando el count
local function feed(seq, count)
  local prefix = (count and count > 0) and tostring(count) or ""
  -- "i" = insertar al frente del typeahead (respeta teclas pendientes),
  -- "n" = sin remapear (ejecuta el comando nativo, no vuelve a entrar aquí)
  api.nvim_feedkeys(prefix .. seq, "in", false)
end

-- ── Punto de entrada ───────────────────────────────────────────────
function M.show(prefix_keys)
  local count = vim.v.count
  local prefix = api.nvim_replace_termcodes(prefix_keys or vim.g.mapleader or " ", true, true, true)
  local builtin = BUILTIN[prefix]
  local fallthrough = builtin ~= nil -- prefijos integrados: reenviar lo desconocido

  local seq = prefix
  local first = true -- primer nivel: Vim ya esperó timeoutlen -> popup inmediato
  while true do
    local exact_user, exact_builtin, longer = nil, nil, {}
    for _, c in ipairs(candidates(seq, builtin)) do
      if #c.raw == #seq then
        if c.raw ~= prefix then -- ignorar el propio disparador del prefijo
          if c.builtin then
            exact_builtin = c
          else
            exact_user = c
          end
        end
      else
        longer[#longer + 1] = c
      end
    end

    if #longer == 0 then
      if exact_user then
        execute(exact_user.mapping)
      elseif exact_builtin or fallthrough then
        feed(seq, count)
      end
      return
    end

    local ch = read_key(seq, build_entries(seq, longer), first)
    first = false
    if not ch or ch == "" or ch == "\27" then -- <Esc> / cancelar
      if ch == "\27" then
        return
      end
      -- sin tecla válida: en prefijos integrados, dejar pasar lo tecleado
      if fallthrough then
        feed(seq, count)
      end
      return
    end
    seq = seq .. ch
  end
end

return M
