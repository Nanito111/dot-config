-- Resalta tags TODO/FIXME/… en el código y ofrece un picker que los lista en todo el
-- proyecto (con ripgrep). Plugin-free: el resaltado son extmarks; el listado, rg --json.
local api = vim.api
local palette = require("config.palette")
local theme = require("config.theme")
local M = {}

local ns = api.nvim_create_namespace("todo")

-- Palabra clave -> grupo de highlight. En MAYÚSCULAS y seguida de ':' (así "TODO" suelto en
-- prosa, o dentro de "TODOS", no cuenta). Los dos puntos entran en el resaltado.
local KEYWORDS = {
  TODO = "TodoTODO",
  FIXME = "TodoFIX",
  BUG = "TodoFIX",
  HACK = "TodoHACK",
  WARN = "TodoHACK",
  WARNING = "TodoHACK",
  XXX = "TodoHACK",
  NOTE = "TodoNOTE",
  PERF = "TodoPERF",
  OPTIM = "TodoPERF",
}

-- Estilo "badge": fondo de color + texto oscuro. Se define fg Y bg (no solo fg) porque el
-- resaltado nativo/treesitter ya pinta estas palabras con fondo (Todo, @comment.todo…); con
-- solo fg, ese fondo se colaba por debajo y quedaba texto de color sobre color.
-- Los tonos salen de diag_* (derivados por propósito): con algunos temas palette.yellow y
-- .cyan colapsan sobre .blue y TODO/NOTE acababan del mismo color.
local function set_hl()
  local function badge(name, color)
    api.nvim_set_hl(0, name, { fg = palette.bg, bg = color, bold = true })
  end
  badge("TodoTODO", palette.diag_info)
  badge("TodoFIX", palette.diag_error)
  badge("TodoHACK", palette.diag_warn)
  badge("TodoNOTE", palette.diag_hint)
  badge("TodoPERF", palette.green)
end
theme.register(set_hl)
set_hl()

local MAX_LINES = 5000 -- por encima, no resaltar (evita penalizar archivos enormes)

local function eligible(buf)
  return api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buftype == ""
    and api.nvim_buf_line_count(buf) <= MAX_LINES
end

-- Dibuja las marcas en un buffer (toda la extensión; hay tope de líneas)
local function render(buf)
  if not eligible(buf) then
    return
  end
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    for kw, group in pairs(KEYWORDS) do
      local from = 1
      while true do
        local s, e = line:find("%f[%w]" .. kw .. ":", from)
        if not s then
          break
        end
        pcall(api.nvim_buf_set_extmark, buf, ns, i - 1, s - 1, { end_col = e, hl_group = group })
        from = e + 1
      end
    end
  end
end

-- Debounce por buffer (el resaltado es O(líneas·palabras); no en cada pulsación)
local timers = {}
local function schedule(buf)
  if not timers[buf] then
    timers[buf] = vim.uv.new_timer()
  end
  timers[buf]:start(150, 0, vim.schedule_wrap(function()
    render(buf)
  end))
end

local group = api.nvim_create_augroup("Todo", { clear = true })
api.nvim_create_autocmd({ "BufWinEnter", "TextChanged", "InsertLeave" }, {
  group = group,
  callback = function(a)
    schedule(a.buf)
  end,
})
api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = group,
  callback = function(a)
    local t = timers[a.buf]
    if t then
      t:stop()
      t:close()
      timers[a.buf] = nil
    end
  end,
})

-- ── Picker: TODOs de todo el proyecto (rg) ─────────────────────────
local function rg_pattern()
  local kws = {}
  for kw in pairs(KEYWORDS) do
    kws[#kws + 1] = kw
  end
  return "\\b(" .. table.concat(kws, "|") .. "):"
end

function M.pick()
  if vim.fn.executable("rg") == 0 then
    vim.notify("ripgrep (rg) no está en el PATH", vim.log.levels.ERROR)
    return
  end
  -- Una sola pasada (los tags son un conjunto fijo); luego se filtra fuzzy sobre el
  -- resultado. --case-sensitive: los tags van en MAYÚSCULAS.
  vim.system(
    { "rg", "--json", "--case-sensitive", "--path-separator", "/", "-e", rg_pattern() },
    { text = true },
    vim.schedule_wrap(function(res)
      local items, meta, seen = {}, {}, {}
      for line in (res.stdout or ""):gmatch("[^\r\n]+") do
        local ok, ev = pcall(vim.json.decode, line)
        if ok and type(ev) == "table" and ev.type == "match" then
          local d = ev.data
          local path = d.path and d.path.text
          local text = (d.lines and d.lines.text or ""):gsub("[\r\n]+$", ""):gsub("^%s+", "")
          local sm = (d.submatches or {})[1]
          if path and sm and sm.start then
            local col = sm.start + 1
            local item = string.format("%s:%d: %s", path, d.line_number, text)
            if not seen[item] then
              seen[item] = true
              items[#items + 1] = item
              meta[item] = { path = path, lnum = d.line_number, col = col, end_col = sm["end"] + 1 }
            end
          end
        end
      end
      if #items == 0 then
        vim.notify("Sin TODOs en el proyecto", vim.log.levels.INFO, { title = "TODO" })
        return
      end
      require("plugins.local.picker").pick({
        title = "TODOs (" .. #items .. ")",
        items = items,
        backdrop = true,
        preview = function(item)
          local it = meta[item]
          if it then
            return {
              path = vim.fn.fnamemodify(it.path, ":p"),
              lnum = it.lnum,
              col = it.col,
              hl = { end_lnum = it.lnum, end_col = it.end_col, group = "Search" },
            }
          end
        end,
        on_select = function(item, origin)
          local it = meta[item]
          if not it then
            return
          end
          if origin and api.nvim_win_is_valid(origin) then
            api.nvim_set_current_win(origin)
          end
          vim.cmd("edit " .. vim.fn.fnameescape(it.path))
          pcall(api.nvim_win_set_cursor, 0, { it.lnum, it.col - 1 })
        end,
      })
    end)
  )
end

api.nvim_create_user_command("Todos", M.pick, { desc = "Listar los TODO/FIXME del proyecto" })

-- Dibujar en los buffers ya cargados (arranque / :ReloadConfig)
for _, buf in ipairs(api.nvim_list_bufs()) do
  if api.nvim_buf_is_loaded(buf) then
    render(buf)
  end
end

return M
