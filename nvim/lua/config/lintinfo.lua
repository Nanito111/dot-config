-- Información de los linters (nvim-lint) del buffer actual, al estilo de :LspInfo pero para
-- linters: filetype, linters configurados, su comando y si el binario está en el PATH, cuáles
-- están analizando, y el ÚLTIMO ERROR de cada uno (p. ej. "No dialect was specified"), que
-- nvim-lint descarta. Ese error lo captura config.lintstatus ejecutando el linter con stderr.
local api = vim.api
local M = {}

-- Parte un texto largo en líneas de a lo sumo `w` columnas (corte por palabras).
local function wrap(text, w)
  local out = {}
  for _, para in ipairs(vim.split(text, "\n", { plain = true })) do
    local line = ""
    for word in para:gmatch("%S+") do
      if line == "" then
        line = word
      elseif #line + 1 + #word <= w then
        line = line .. " " .. word
      else
        out[#out + 1] = line
        line = word
      end
    end
    out[#out + 1] = line
  end
  return out
end

local function render(ft, names, running, results)
  local lines, marks = {}, {}
  local function add(text, hl, col, end_col)
    lines[#lines + 1] = text
    if hl then
      marks[#marks + 1] = { row = #lines - 1, col = col or 0, end_col = end_col or #text, hl = hl }
    end
  end

  add("  Linters (nvim-lint)", "Title")
  add("")
  add("  Filetype: " .. (ft ~= "" and ft or "(ninguno)"), "Comment")
  add("")

  if #names == 0 then
    add("  Sin linters configurados para este filetype.", "Comment")
  else
    add("  Configurados:")
    local w = 0
    for _, n in ipairs(names) do
      w = math.max(w, #n)
    end
    for _, n in ipairs(names) do
      local r = results[n] or {}
      local cmd = r.cmd
      local found = r.found
      -- ✓ ok · ⚠ binario presente pero con error de config · ✗ no está en el PATH
      local badge, badge_hl = "✓", "DiagnosticOk"
      if not found then
        badge, badge_hl = "✗", "DiagnosticError"
      elseif r.msg then
        badge, badge_hl = "⚠", "DiagnosticWarn"
      end
      local pad = string.rep(" ", w - #n + 2)
      local tail = cmd and (cmd .. (found and "" or "  (no está en el PATH)")) or "(sin comando)"
      add("    " .. badge .. " " .. n .. pad .. tail)
      local row = #lines - 1
      marks[#marks + 1] = { row = row, col = 4, end_col = 4 + #badge, hl = badge_hl }
      if running[n] then
        marks[#marks + 1] = { row = row, col = 6, end_col = 6 + #n, hl = "DiagnosticInfo" }
      end
      -- problema detectado en stderr (config/entorno): se muestra debajo, resaltado
      if r.msg then
        for _, ml in ipairs(wrap(r.msg, 66)) do
          add("        " .. ml, "DiagnosticWarn")
        end
      end
    end
  end

  local running_list = vim.tbl_keys(running)
  if #running_list > 0 then
    add("")
    add("  Analizando ahora: " .. table.concat(running_list, ", "), "DiagnosticInfo")
  end

  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, api.nvim_strwidth(l))
  end
  width = math.min(math.max(width + 4, 40), vim.o.columns - 4)

  local f = require("plugins.local.ui").float.open({
    width = width,
    height = #lines,
    enter = true,
    title = " LintInfo ",
    title_pos = "center",
    backdrop = true,
    close_keys = { "q", "<Esc>" },
    close_on_leave = true,
    wo = { wrap = false, cursorline = false },
  })
  vim.bo[f.buf].modifiable = true
  api.nvim_buf_set_lines(f.buf, 0, -1, false, lines)
  vim.bo[f.buf].modifiable = false
  local ns = api.nvim_create_namespace("lintinfo")
  for _, m in ipairs(marks) do
    pcall(api.nvim_buf_set_extmark, f.buf, ns, m.row, m.col, { end_col = m.end_col, hl_group = m.hl })
  end
end

function M.show()
  if not package.loaded["lint"] and not pcall(require, "lint") then
    vim.notify("nvim-lint no está disponible", vim.log.levels.WARN, { title = "LintInfo" })
    return
  end
  local lint = require("lint")
  local ft = vim.bo.filetype
  local names = (lint.linters_by_ft and lint.linters_by_ft[ft]) or {}
  local running = {}
  for _, n in ipairs(lint.get_running and lint.get_running(0) or {}) do
    running[n] = true
  end

  if #names == 0 then
    render(ft, names, running, {})
    return
  end

  -- Sondear cada linter (captura su stderr) y dibujar cuando lleguen todos.
  local status = require("config.lintstatus")
  local bufnr = api.nvim_get_current_buf()
  local results, pending = {}, #names
  for _, n in ipairs(names) do
    status.probe(n, bufnr, function(entry)
      results[n] = entry or {}
      pending = pending - 1
      if pending == 0 then
        render(ft, names, running, results)
      end
    end)
  end
end

return M
