-- Controlador de "lista imantada": el cursor no descansa nunca en filas no seleccionables
-- (cabeceras/blancos); al moverse salta a la fila seleccionable más cercana EN EL SENTIDO del
-- movimiento (o el contrario si no hay), y marca la fila activa con un ▸. Es lo genuinamente
-- compartido (y sutil) entre el panel de settings y la tabla de indentación.
--
-- El consumidor sigue renderizando sus propias líneas/colores; solo:
--   1. tras cada render llama `ctrl.set_rows(rows)` con el mapa lnum -> value|false
--      (false = no seleccionable; usar false y NO nil para que #rows sea fiable),
--   2. engancha su autocomando CursorMoved a `ctrl.on_cursor`,
--   3. lee la selección con `ctrl.current()`.
local api = vim.api
local M = {}

-- opts: buf (obligatorio), win | get_win() (la ventana donde vive), marker = { text, hl }?
function M.new(opts)
  local buf = opts.buf
  local ns = api.nvim_create_namespace("ui_menu_marker_" .. buf) -- marcador, aislado por buffer
  local marker = opts.marker
  local rows = {}
  local last

  local function win()
    if opts.get_win then
      return opts.get_win()
    end
    return opts.win
  end

  local function scan(from, dir)
    local n = #rows
    local a = from
    while a >= 1 and a <= n do
      if rows[a] then
        return a
      end
      a = a + dir
    end
  end

  local function draw_marker(lnum)
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    if marker then
      pcall(api.nvim_buf_set_extmark, buf, ns, lnum - 1, 0, {
        virt_text = { { marker.text, marker.hl } },
        virt_text_pos = "overlay",
      })
    end
  end

  local self = {}

  function self.set_rows(r)
    rows = r
  end

  function self.on_cursor()
    local w = win()
    if not (w and api.nvim_win_is_valid(w)) then
      return
    end
    local pos = api.nvim_win_get_cursor(w)
    local lnum = pos[1]
    if not rows[lnum] then
      local dir = (last and lnum < last) and -1 or 1
      local target = scan(lnum, dir) or scan(lnum, -dir)
      if not target then
        return -- no hay ninguna fila seleccionable
      end
      api.nvim_win_set_cursor(w, { target, 0 })
      lnum = target
    elseif pos[2] ~= 0 then
      api.nvim_win_set_cursor(w, { lnum, 0 }) -- fijar a la 1.ª columna (cursor oculto limpio)
    end
    last = lnum
    draw_marker(lnum)
  end

  function self.current()
    local w = win()
    if not (w and api.nvim_win_is_valid(w)) then
      return nil
    end
    return rows[api.nvim_win_get_cursor(w)[1]]
  end

  return self
end

return M
