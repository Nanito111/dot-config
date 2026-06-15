-- Popup del which-key y lectura de la siguiente tecla con su lógica de retardo.
local api = vim.api
local M = {}

-- Retardo antes de mostrar el popup en niveles ANIDADOS: usamos el mismo
-- 'timeoutlen' de Vim que rige el primer nivel, para un solo botón coherente.
-- (El primer nivel es inmediato porque Vim ya esperó 'timeoutlen' antes de M.show.)
local function delay()
  return vim.o.timeoutlen
end

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
-- Niveles siguientes: programar el popup tras 'timeoutlen' ms y bloquear en
-- getcharstr(); si pulsas antes, getcharstr() devuelve ya y el timer se cancela.
function M.read_key(seq, entries, immediate)
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

return M
