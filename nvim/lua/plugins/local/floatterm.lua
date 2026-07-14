local api = vim.api
local M = {}

-- Estado por nombre+tab: una instancia por workspace. { buf = <bufnr>, win = <winid> }
local state = {}

-- Abre una ventana flotante centrada que muestra el buffer dado
local function open_win(buf, title)
  local cols = vim.o.columns
  local rows = vim.o.lines
  local width = math.floor(cols * 0.85)
  local height = math.floor(rows * 0.9)
  return api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((rows - height - 2) / 2),
    col = math.floor((cols - width) / 2),
    style = "minimal",
    title = " " .. title .. " ",
    title_pos = "center",
  })
end

-- Alterna un terminal flotante que ejecuta `cmd` (lista de argumentos).
-- `name` identifica la instancia para mantener su proceso vivo entre toggles.
function M.toggle(name, cmd)
  -- Verificar que el binario exista antes de intentar arrancarlo
  if vim.fn.executable(cmd[1]) == 0 then
    vim.notify(
      string.format("'%s' no está en el PATH; instálalo para usar esta función", cmd[1]),
      vim.log.levels.ERROR
    )
    return
  end

  -- Una instancia por tab (workspace): así cada cwd tiene su propio proceso
  local key = name .. "#" .. api.nvim_get_current_tabpage()
  local st = state[key] or {}
  state[key] = st

  -- Si ya está visible, ocultarlo (el proceso sigue corriendo)
  if st.win and api.nvim_win_is_valid(st.win) then
    api.nvim_win_close(st.win, true)
    st.win = nil
    return
  end

  -- Reutilizar el buffer/proceso existente si sigue vivo
  if st.buf and api.nvim_buf_is_valid(st.buf) then
    st.win = open_win(st.buf, name)
    vim.cmd("startinsert")
    return
  end

  -- Crear buffer + proceso nuevos, anclados al cwd de la tab actual
  st.buf = api.nvim_create_buf(false, true)
  st.tab = api.nvim_get_current_tabpage() -- tab dueña, para limpiar al cerrarla
  vim.bo[st.buf].bufhidden = "hide"
  vim.b[st.buf].term_label = name -- etiqueta para mostrar en la statusline
  st.win = open_win(st.buf, name)
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = vim.fn.getcwd(), -- cwd efectivo de la tab (respeta tcd)
    on_exit = function()
      if st.win and api.nvim_win_is_valid(st.win) then
        api.nvim_win_close(st.win, true)
      end
      if st.buf and api.nvim_buf_is_valid(st.buf) then
        api.nvim_buf_delete(st.buf, { force = true })
      end
      state[key] = nil
    end,
  })
  vim.cmd("startinsert")
end

-- Al cerrar una tab (workspace), matar las instancias que vivían en ella.
-- Borrar el buffer de terminal termina su proceso.
api.nvim_create_autocmd("TabClosed", {
  group = api.nvim_create_augroup("FloatTerm", { clear = true }), -- agrupado: no duplica al recargar
  desc = "Cerrar terminales flotantes de la tab cerrada",
  callback = function()
    for key, st in pairs(state) do
      if st.tab and not api.nvim_tabpage_is_valid(st.tab) then
        if st.buf and api.nvim_buf_is_valid(st.buf) then
          api.nvim_buf_delete(st.buf, { force = true })
        end
        state[key] = nil
      end
    end
  end,
})

return M
