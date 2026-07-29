-- Detalles de un paquete: builder de líneas (lo usan el popup y el preview del picker) +
-- el popup flotante (ui.float).
local ui = require("plugins.local.ui")
local M = {}

-- Líneas de descripción de un paquete de mason (spec).
function M.lines(pkg)
  local s = pkg.spec or {}
  local L = { pkg.name, "" }
  if s.description and s.description ~= "" then
    for _, l in ipairs(vim.split(vim.trim(s.description), "\n")) do
      L[#L + 1] = l
    end
    L[#L + 1] = ""
  end
  local function kv(k, v)
    if v and v ~= "" then
      L[#L + 1] = k .. ": " .. v
    end
  end
  kv("Categorías", table.concat(s.categories or {}, ", "))
  kv("Lenguajes", table.concat(s.languages or {}, ", "))
  kv("Licencia", table.concat(s.licenses or {}, ", "))
  kv("Homepage", s.homepage)
  local oki, iv = pcall(pkg.get_installed_version, pkg)
  if oki and iv then
    kv("Instalada", iv)
  end
  local okl, lv = pcall(pkg.get_latest_version, pkg)
  if okl and lv then
    kv("Última", lv)
  end
  return L
end

function M.open(pkg)
  local lines = M.lines(pkg)
  local width = 40
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 4)
  end
  width = math.min(width, math.floor(vim.o.columns * 0.7))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  ui.float.open({
    buf = buf,
    enter = true,
    width = width,
    height = math.min(#lines, vim.o.lines - 6),
    title = " " .. pkg.name .. " ",
    title_pos = "center",
    backdrop = true,
    close_keys = { "q", "<Esc>" },
    wo = { wrap = true, linebreak = true, number = false, relativenumber = false, signcolumn = "no", cursorline = false },
  })
end

return M
