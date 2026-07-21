-- Confirmación flotante SÍNCRONA (plugin-free): reemplaza a vim.fn.confirm en los
-- sitios donde se usa. Mantiene su firma y semántica para no cambiar el flujo:
--   confirm(msg, choices, default) -> índice elegido (1-based) o 0 si se cancela.
--   choices como en vim.fn.confirm: "&Sí\n&No" (la letra tras '&' es el acelerador).
-- Navega con ←/→ o h/l, confirma con Enter, cancela con Esc, o pulsa el acelerador.
local api = vim.api
local M = {}

local LEFT = api.nvim_replace_termcodes("<Left>", true, false, true)
local RIGHT = api.nvim_replace_termcodes("<Right>", true, false, true)

-- opts (opcional): { backdrop = true } para oscurecer el editor detrás del popup.
function M.confirm(msg, choices, default, opts)
  -- parsear etiquetas y aceleradores
  local labels, accels = {}, {}
  for c in ((choices or "&OK") .. "\n"):gmatch("(.-)\n") do
    if c ~= "" then
      local a = c:match("&(.)")
      labels[#labels + 1] = (c:gsub("&", ""))
      accels[#accels + 1] = a and a:lower() or false
    end
  end
  local sel = math.max(1, math.min(default or 1, #labels))

  -- contenido: mensaje + línea de botones "[ Sí ]  [ No ]"
  local content = {}
  for _, l in ipairs(vim.split(msg or "", "\n")) do
    content[#content + 1] = " " .. l .. " "
  end
  content[#content + 1] = ""
  local btn, ranges = " ", {}
  for i, lab in ipairs(labels) do
    local text = "[ " .. lab .. " ]"
    ranges[i] = { #btn, #btn + #text }
    btn = btn .. text .. "  "
  end
  content[#content + 1] = btn
  local btn_row = #content - 1

  local width = 1
  for _, l in ipairs(content) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.min(width + 1, math.floor(vim.o.columns * 0.8))

  -- centrar la línea de botones dentro del ancho del popup (y desplazar los rangos del
  -- resaltado para que sigan cayendo sobre los botones)
  local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(btn)) / 2))
  if pad > 0 then
    content[#content] = string.rep(" ", pad) .. btn
    for _, r in ipairs(ranges) do
      r[1], r[2] = r[1] + pad, r[2] + pad
    end
  end

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
  -- backdrop opcional (por debajo del popup, que usa zindex 250)
  local fl = require("plugins.local.ui").float.open({
    buf = buf,
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = #content,
    title = " Confirmar ",
    title_pos = "center",
    focusable = false,
    noautocmd = true,
    zindex = 250,
    backdrop = (opts and opts.backdrop) and { zindex = 240 } or nil,
  })
  local win = fl.win
  local ns = api.nvim_create_namespace("confirm_btn")
  local function draw()
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local r = ranges[sel]
    api.nvim_buf_add_highlight(buf, ns, "Visual", btn_row, r[1], r[2])
    vim.cmd("redraw")
  end
  draw()

  local result = 0
  while true do
    local ok, ch = pcall(vim.fn.getcharstr)
    if not ok then
      break
    end
    if ch == "\r" or ch == "\n" then
      result = sel
      break
    elseif ch == "\27" then -- Esc = cancelar
      result = 0
      break
    elseif ch == "h" or ch == LEFT then
      sel = (sel - 2) % #labels + 1
      draw()
    elseif ch == "l" or ch == RIGHT then
      sel = sel % #labels + 1
      draw()
    else
      local lc = ch:lower()
      for i, a in ipairs(accels) do
        if a == lc then
          result = i
          break
        end
      end
      if result ~= 0 then
        break
      end
    end
  end

  fl.close()
  return result
end

return M
