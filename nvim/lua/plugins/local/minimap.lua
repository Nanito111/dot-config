-- Minimapa propio (plugin-free) en una VENTANA PROPIA (split), no un flotante: reserva su
-- espacio como el sidebar, así no tapa el código. Codifica el buffer en braille (2×4 puntos
-- por carácter), resalta el viewport visible y la línea del cursor, y sincroniza con el
-- scroll. Off por defecto; <leader>um lo alterna. Va al lado OPUESTO al sidebar y se
-- auto-oculta en buffers especiales / flotantes.
local api = vim.api
local M = {}

local WIDTH = 20 -- columnas del minimapa
local MAXW = 160 -- ancho de referencia (columnas fuente -> puntos); más allá se recorta

local ns = api.nvim_create_namespace("minimap")
local enabled = false
local mm_win, mm_buf -- ventana/buffer del minimapa
local src_win -- ventana de código que se está reflejando
local timer -- debounce del re-encode
local last -- { L, H, scale } del último render (para mapear filas<->líneas)

-- ── Braille: bit de cada subcelda (dx 0..1, dy 0..3) ───────────────
local BASE = 0x2800
local DOT = {
  [0] = { 0x01, 0x02, 0x04, 0x40 }, -- columna izquierda (dy 0..3)
  [1] = { 0x08, 0x10, 0x20, 0x80 }, -- columna derecha
}

-- Mapea una línea fuente (1-based) a la fila del minimapa (0-based) y viceversa.
local function line_to_row(line)
  if not last then
    return 0
  end
  if last.scale then
    return math.floor((line - 1) * last.H / last.L)
  end
  return math.floor((line - 1) / 4)
end
local function row_to_line(row)
  if not last then
    return 1
  end
  if last.scale then
    return math.floor(row * last.L / last.H) + 1
  end
  return row * 4 + 1
end

-- Codifica `lines` en `H` filas de `WIDTH` glifos braille.
local function encode(lines, H)
  local L = #lines
  local dot_rows, dot_cols = H * 4, WIDTH * 2
  local scale = L > dot_rows

  local refw = 40
  for _, ln in ipairs(lines) do
    if #ln > refw then
      refw = #ln
    end
    if refw >= MAXW then
      refw = MAXW
      break
    end
  end

  local grid = {} -- grid[dot_row * dot_cols + dot_col] = true
  for i = 1, L do
    local ln = lines[i]
    local r = scale and math.floor((i - 1) * dot_rows / L) or (i - 1)
    if r >= dot_rows then
      r = dot_rows - 1
    end
    local rowbase = r * dot_cols
    local maxj = math.min(#ln, refw)
    for j = 1, maxj do
      local b = ln:byte(j)
      if b ~= 32 and b ~= 9 then -- no es espacio ni tab = "tinta"
        local c = math.floor((j - 1) * dot_cols / refw)
        if c < dot_cols then
          grid[rowbase + c] = true
        end
      end
    end
  end

  local out = {}
  for cr = 0, H - 1 do
    local chars = {}
    for cc = 0, WIDTH - 1 do
      local dots = 0
      for dx = 0, 1 do
        for dy = 0, 3 do
          if grid[(cr * 4 + dy) * dot_cols + (cc * 2 + dx)] then
            dots = dots + DOT[dx][dy + 1]
          end
        end
      end
      chars[#chars + 1] = vim.fn.nr2char(BASE + dots)
    end
    out[#out + 1] = table.concat(chars)
  end
  return out, { L = L, H = H, scale = scale }
end

-- ── Resaltados desde la paleta ─────────────────────────────────────
local function set_hl()
  local p = require("config.palette")
  api.nvim_set_hl(0, "MinimapNormal", { fg = p.comment, bg = p.bg })
  api.nvim_set_hl(0, "MinimapView", { bg = p.bg_highlight }) -- rango visible en pantalla
  api.nvim_set_hl(0, "MinimapCursor", { bg = p.blue, fg = p.bg }) -- línea del cursor
end

-- ¿esta ventana es de código "normal" (no minimapa, no flotante, no buffer especial)?
local function is_code_win(win)
  if not (win and api.nvim_win_is_valid(win)) then
    return false
  end
  if api.nvim_win_get_config(win).relative ~= "" then
    return false
  end
  local buf = api.nvim_win_get_buf(win)
  if win == mm_win then
    return false
  end
  local ft = vim.bo[buf].filetype
  return ft ~= "dashboard"
    and ft ~= "explorer"
    and ft ~= "settings"
    and ft ~= "mason"
    and ft ~= "netrw"
    and ft ~= "minimap"
    and vim.bo[buf].buftype == ""
end

-- Reaplica los extmarks del viewport + línea del cursor (barato: sin re-encode).
local function update_view()
  if not (mm_buf and api.nvim_buf_is_valid(mm_buf) and last) then
    return
  end
  api.nvim_buf_clear_namespace(mm_buf, ns, 0, -1)
  if not (src_win and api.nvim_win_is_valid(src_win)) then
    return
  end
  local top = vim.fn.line("w0", src_win)
  local bot = vim.fn.line("w$", src_win)
  local cur = api.nvim_win_get_cursor(src_win)[1]
  local r0, r1 = line_to_row(top), line_to_row(bot)
  for r = r0, r1 do
    pcall(api.nvim_buf_set_extmark, mm_buf, ns, r, 0, { line_hl_group = "MinimapView", hl_eol = true })
  end
  pcall(api.nvim_buf_set_extmark, mm_buf, ns, line_to_row(cur), 0, {
    line_hl_group = "MinimapCursor",
    hl_eol = true,
    priority = 200,
  })
end

-- Re-encodea el buffer de código en el minimapa (y reaplica el viewport).
local function render()
  if not (mm_win and api.nvim_win_is_valid(mm_win) and mm_buf and api.nvim_buf_is_valid(mm_buf)) then
    return
  end
  if not is_code_win(src_win) then
    return
  end
  local H = api.nvim_win_get_height(mm_win)
  if H < 1 then
    return
  end
  local lines = api.nvim_buf_get_lines(api.nvim_win_get_buf(src_win), 0, -1, false)
  local out, meta = encode(lines, H)
  last = meta
  vim.bo[mm_buf].modifiable = true
  api.nvim_buf_set_lines(mm_buf, 0, -1, false, out)
  vim.bo[mm_buf].modifiable = false
  update_view()
end

-- Debounce del re-encode (ediciones/scroll disparan ráfagas).
local function schedule_render()
  if not timer then
    timer = vim.uv.new_timer()
  end
  timer:stop()
  timer:start(80, 0, vim.schedule_wrap(render))
end

-- ── Ciclo de vida de la ventana ────────────────────────────────────
local function side()
  return require("config.settings").value("ui.sidebar_side", "left") == "left" and "right" or "left"
end

local function open()
  if mm_win and api.nvim_win_is_valid(mm_win) then
    return
  end
  local code = api.nvim_get_current_win()
  if not is_code_win(code) then
    return
  end
  src_win = code
  if not (mm_buf and api.nvim_buf_is_valid(mm_buf)) then
    mm_buf = api.nvim_create_buf(false, true)
    vim.bo[mm_buf].buftype = "nofile"
    vim.bo[mm_buf].bufhidden = "hide"
    vim.bo[mm_buf].swapfile = false
    vim.bo[mm_buf].filetype = "minimap"
    -- Solo clickeable: el clic salta a esa zona y devuelve el foco al código. No se opera
    -- por teclado como una ventana normal; se neutraliza lo que la haría sentir de archivo.
    for _, k in ipairs({ "<LeftMouse>", "<2-LeftMouse>" }) do
      vim.keymap.set("n", k, function()
        M.jump()
      end, { buffer = mm_buf, silent = true, nowait = true })
    end
    for _, k in ipairs({ "<Tab>", "<S-Tab>", "<leader>x" }) do
      vim.keymap.set("n", k, "<Nop>", { buffer = mm_buf, silent = true, nowait = true })
    end
  end
  -- split a lo alto completo del lado correspondiente (como el sidebar)
  vim.cmd(side() == "left" and "noautocmd topleft vsplit" or "noautocmd botright vsplit")
  mm_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(mm_win, mm_buf)
  api.nvim_win_set_width(mm_win, WIDTH)
  require("plugins.local.ui.win").set_opts(mm_win, {
    winfixwidth = true,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    list = false,
    wrap = false,
    cursorline = false,
    winhighlight = "Normal:MinimapNormal,NormalNC:MinimapNormal,EndOfBuffer:MinimapNormal",
    statuscolumn = "",
  })
  api.nvim_set_current_win(code) -- devolver el foco al código
  render()
end

local function close()
  if mm_win and api.nvim_win_is_valid(mm_win) then
    pcall(api.nvim_win_close, mm_win, true)
  end
  mm_win = nil
end

-- Salta el código a la zona pulsada en el minimapa (fila bajo el ratón).
function M.jump()
  if not (src_win and api.nvim_win_is_valid(src_win) and mm_win and api.nvim_win_is_valid(mm_win)) then
    return
  end
  local mp = vim.fn.getmousepos()
  local row = (mp.winid == mm_win and mp.line > 0) and (mp.line - 1) or (api.nvim_win_get_cursor(mm_win)[1] - 1)
  local target = math.max(1, math.min(row_to_line(row), api.nvim_buf_line_count(api.nvim_win_get_buf(src_win))))
  api.nvim_set_current_win(src_win)
  pcall(api.nvim_win_set_cursor, src_win, { target, 0 })
  vim.cmd("normal! zz")
end

-- Abre/cierra según el estado activado y las ventanas de la tab.
local function reconcile()
  if not enabled then
    return close()
  end
  local cur = api.nvim_get_current_win()
  if is_code_win(cur) then
    src_win = cur
    if mm_win and api.nvim_win_is_valid(mm_win) then
      render()
    else
      open()
    end
    return
  end
  -- El foco pasó a un flotante, al sidebar o a un buffer especial: NO ocultar el minimapa
  -- por eso. Solo se cierra si ya no queda NINGUNA ventana de código en la tab (p. ej.
  -- dashboard o terminal a pantalla completa).
  if not is_code_win(src_win) then
    src_win = nil
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
      if is_code_win(w) then
        src_win = w
        break
      end
    end
  end
  if not src_win then
    close()
  elseif mm_win and api.nvim_win_is_valid(mm_win) then
    render() -- mantener el mapa reflejando la ventana de código vigente
  end
end

local did_autocmds = false
local function ensure_autocmds()
  if did_autocmds then
    return
  end
  did_autocmds = true
  require("config.theme").register(set_hl)
  local grp = api.nvim_create_augroup("Minimap", { clear = true })
  api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = grp,
    callback = vim.schedule_wrap(reconcile),
  })
  api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = grp,
    callback = function(a)
      if enabled and a.buf == (src_win and api.nvim_win_is_valid(src_win) and api.nvim_win_get_buf(src_win)) then
        schedule_render()
      end
    end,
  })
  api.nvim_create_autocmd({ "CursorMoved", "WinScrolled" }, {
    group = grp,
    callback = function()
      if enabled and is_code_win(api.nvim_get_current_win()) then
        src_win = api.nvim_get_current_win()
        update_view() -- barato: solo mueve el resaltado del viewport
      end
    end,
  })
  api.nvim_create_autocmd("WinResized", {
    group = grp,
    callback = function()
      if enabled then
        schedule_render()
      end
    end,
  })
end

function M.toggle()
  ensure_autocmds()
  enabled = not enabled
  reconcile()
  vim.notify(
    enabled and "Minimapa activado" or "Minimapa desactivado",
    vim.log.levels.INFO,
    { title = "Minimap", ephemeral = true }
  )
end

return M
