-- Rename del LSP con confirmación y undo (plugin-free).
-- Flujo: pide el nombre nuevo -> pide al servidor el WorkspaceEdit (sin aplicarlo) ->
-- muestra un popup con la lista de archivos afectados (navegable j/k) -> al confirmar,
-- guarda un snapshot del contenido previo de cada archivo, aplica el rename y avisa.
-- :LspRenameUndo (o el keymap) restaura los snapshots -> revierte todo al instante.
local api = vim.api
local M = {}

local snapshot = nil -- { { buf, lines, modified }, ... } del último rename

-- Archivos afectados por un WorkspaceEdit, con su lista de ediciones (para el preview)
function M.edit_files(edit)
  local out, seen = {}, {}
  local function add(uri, edits)
    if not seen[uri] then
      seen[uri] = true
      out[#out + 1] = { uri = uri, edits = edits or {} }
    end
  end
  if edit.documentChanges then
    for _, dc in ipairs(edit.documentChanges) do
      if dc.textDocument and dc.edits then
        add(dc.textDocument.uri, dc.edits)
      end
    end
  elseif edit.changes then
    for uri, edits in pairs(edit.changes) do
      add(uri, edits)
    end
  end
  table.sort(out, function(a, b)
    return a.uri < b.uri
  end)
  return out
end

local ns = api.nvim_create_namespace("lsprename_confirm")
local ns_prev = api.nvim_create_namespace("lsprename_preview")

-- Popup de DOS PANELES: lista de archivos (izquierda) + preview (derecha).
--   j/k          cambian de archivo (y el preview)
--   <C-n>/<C-p>  saltan entre los cambios del archivo en el preview
--   ←/→ (o h/l)  eligen botón [ Sí ] / [ No ]
--   ⏎/Espacio    confirman la selección; y/n atajo; q/Esc cancelan
-- El preview muestra el archivo YA con el rename aplicado (texto nuevo resaltado con
-- DiffText). Se construye en un buffer scratch, sin tocar tus archivos reales.
function M.confirm(files, title, encoding, on_confirm)
  local total = #files
  local W = math.min(math.floor(vim.o.columns * 0.85), 120)
  local H = math.min(math.floor(vim.o.lines * 0.7), 26)
  local row = math.floor((vim.o.lines - H) / 2)
  local col = math.floor((vim.o.columns - W) / 2)
  local list_w = math.max(24, math.min(38, math.floor(W * 0.32)))
  local prev_w = W - list_w - 3

  -- Oscurecer el fondo (backdrop) para diferenciar el diálogo del buffer de código
  local close_backdrop = require("plugins.local.backdrop").open()

  -- ── Preview (derecha, sin foco): buffer scratch con el resultado ──
  local preview_buf = api.nvim_create_buf(false, true)
  local preview_win = api.nvim_open_win(preview_buf, false, {
    relative = "editor", row = row, col = col + list_w + 3, width = prev_w, height = H,
    style = "minimal", title = " Preview ", title_pos = "center",
  })
  vim.wo[preview_win].cursorline = true
  vim.wo[preview_win].number = true

  -- ── Lista + botones (izquierda, con foco) ──
  local list_buf = api.nvim_create_buf(false, true)
  local ranges, btn_row
  do
    local lines = {}
    for i, f in ipairs(files) do
      lines[i] = string.format("  %s  (%d)", vim.fn.fnamemodify(vim.uri_to_fname(f.uri), ":t"), #f.edits)
    end
    lines[#lines + 1] = ""
    local btn = " "
    ranges = {}
    for i, lab in ipairs({ "Sí", "No" }) do
      local t = "[ " .. lab .. " ]"
      ranges[i] = { #btn, #btn + #t }
      btn = btn .. t .. "  "
    end
    lines[#lines + 1] = btn
    btn_row = #lines - 1
    api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
  end
  vim.bo[list_buf].modifiable = false
  vim.b[list_buf].completion = false

  local lh = math.min(total + 2, H)
  local list_win = api.nvim_open_win(list_buf, true, {
    relative = "editor", row = row, col = col, width = list_w, height = lh,
    style = "minimal", title = " " .. title .. " ", title_pos = "left",
    footer = " j/k archivos · C-n/p cambios · ←→ · ⏎ ",
    footer_pos = "center",
  })
  -- scope="local": list_win es la ventana actual; vim.wo[curwin] también fijaría el
  -- default global de cursorline (que el panel de configuración lee)
  api.nvim_set_option_value("cursorline", true, { win = list_win, scope = "local" })

  local sel_file, sel_btn = 1, 1
  local function draw_btn()
    api.nvim_buf_clear_namespace(list_buf, ns, 0, -1)
    api.nvim_buf_add_highlight(list_buf, ns, "Visual", btn_row, ranges[sel_btn][1], ranges[sel_btn][2])
  end
  draw_btn()

  -- posiciones del texto nuevo del archivo actual (para saltar con C-n/C-p)
  local cur_positions, edit_idx = {}, 1

  local function goto_pos(p)
    if not p then
      return
    end
    local n = api.nvim_buf_line_count(preview_buf)
    pcall(api.nvim_win_set_cursor, preview_win, { math.min(p[1] + 1, n), p[2] })
    pcall(api.nvim_win_call, preview_win, function()
      vim.cmd("normal! zz")
    end)
  end

  -- Vuelca el archivo (del buffer si está abierto, si no del disco), aplica el rename
  -- sobre el buffer scratch del preview y resalta el texto nuevo. Como las ediciones de
  -- una misma línea desplazan a las siguientes, se acumula el delta para ubicarlas.
  local function show_preview()
    local f = files[sel_file]
    if not (f and api.nvim_win_is_valid(preview_win)) then
      return
    end
    local path = vim.uri_to_fname(f.uri)
    local rb = vim.fn.bufadd(path)
    local loaded = api.nvim_buf_is_loaded(rb)
    local src = loaded and api.nvim_buf_get_lines(rb, 0, -1, false) or vim.fn.readfile(path)
    local ft = (loaded and vim.bo[rb].filetype ~= "" and vim.bo[rb].filetype)
      or vim.filetype.match({ filename = path })
      or nil

    -- utilidad compartida: vuelca el contenido, aplica el rename encima (apply) y fija
    -- el filetype solo si el archivo es chico (no congela con archivos grandes).
    require("plugins.local.preview").load(preview_buf, src, {
      filetype = ft,
      apply = function(b)
        pcall(vim.lsp.util.apply_text_edits, f.edits, b, encoding or "utf-16")
      end,
    })

    -- resaltar el texto nuevo en sus posiciones ya desplazadas
    api.nvim_buf_clear_namespace(preview_buf, ns_prev, 0, -1)
    local by_line = {}
    for _, e in ipairs(f.edits) do
      local r = e.range
      if r and r.start and r["end"] and r.start.line == r["end"].line then
        local l = r.start.line
        by_line[l] = by_line[l] or {}
        table.insert(by_line[l], { s = r.start.character or 0, e = r["end"].character or 0, txt = e.newText or "" })
      end
    end
    cur_positions = {}
    local nlines = api.nvim_buf_line_count(preview_buf)
    for l, es in pairs(by_line) do
      if l < nlines then
        table.sort(es, function(a, b)
          return a.s < b.s
        end)
        local delta = 0
        for _, ed in ipairs(es) do
          local sc = ed.s + delta
          pcall(api.nvim_buf_set_extmark, preview_buf, ns_prev, l, sc, { end_row = l, end_col = sc + #ed.txt, hl_group = "DiffText" })
          cur_positions[#cur_positions + 1] = { l, sc }
          delta = delta + #ed.txt - (ed.e - ed.s)
        end
      end
    end
    table.sort(cur_positions, function(a, c)
      return a[1] < c[1] or (a[1] == c[1] and a[2] < c[2])
    end)
    edit_idx = 1
    goto_pos(cur_positions[1])
  end
  show_preview()

  local function set_file(i)
    sel_file = math.max(1, math.min(total, i))
    pcall(api.nvim_win_set_cursor, list_win, { sel_file, 0 })
    show_preview()
  end

  local function jump_edit(i)
    if #cur_positions == 0 then
      return
    end
    edit_idx = math.max(1, math.min(#cur_positions, i))
    goto_pos(cur_positions[edit_idx])
  end

  local answered = false
  local function done(okc)
    if answered then
      return
    end
    answered = true
    close_backdrop()
    pcall(api.nvim_win_close, list_win, true)
    pcall(api.nvim_win_close, preview_win, true)
    pcall(api.nvim_buf_delete, preview_buf, { force = true })
    on_confirm(okc)
  end
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = list_buf, nowait = true, silent = true })
  end

  map("j", function() set_file(sel_file + 1) end)
  map("k", function() set_file(sel_file - 1) end)
  map("<C-n>", function() jump_edit(edit_idx + 1) end)
  map("<C-p>", function() jump_edit(edit_idx - 1) end)
  map("h", function() sel_btn = 1; draw_btn() end)
  map("l", function() sel_btn = 2; draw_btn() end)
  map("<Left>", function() sel_btn = 1; draw_btn() end)
  map("<Right>", function() sel_btn = 2; draw_btn() end)
  map("<CR>", function() done(sel_btn == 1) end)
  map("<Space>", function() done(sel_btn == 1) end)
  map("y", function() done(true) end)
  map("n", function() done(false) end)
  map("q", function() done(false) end)
  map("<Esc>", function() done(false) end)
end

-- Guarda a disco un buffer de archivo normal (válido, con nombre y buftype vacío).
-- Silencioso; keepalt para no ensuciar el archivo alterno.
local function write_buf(buf)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  if api.nvim_buf_get_name(buf) == "" or vim.bo[buf].buftype ~= "" then
    return
  end
  api.nvim_buf_call(buf, function()
    pcall(vim.cmd, "silent keepalt write")
  end)
end

-- Guarda el snapshot del contenido actual de los archivos afectados (antes de aplicar)
local function take_snapshot(files)
  snapshot = {}
  for _, f in ipairs(files) do
    local b = vim.fn.bufadd(vim.uri_to_fname(f.uri))
    vim.fn.bufload(b)
    snapshot[#snapshot + 1] = {
      buf = b,
      lines = api.nvim_buf_get_lines(b, 0, -1, false),
    }
  end
end

-- Snapshot + aplicar el WorkspaceEdit. Guarda cada archivo afectado ANTES de aplicar
-- (persiste cualquier cambio pendiente) y DESPUÉS (deja el rename en disco). Devuelve
-- los archivos afectados.
function M.apply(edit, encoding)
  local files = M.edit_files(edit)
  take_snapshot(files)
  for _, s in ipairs(snapshot) do
    write_buf(s.buf) -- guardar antes de aplicar
  end
  vim.lsp.util.apply_workspace_edit(edit, encoding)
  for _, s in ipairs(snapshot) do
    write_buf(s.buf) -- guardar después de aplicar
  end
  return files
end

-- Punto de entrada: reemplaza a vim.lsp.buf.rename
function M.rename()
  local bufnr = api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/rename" })
  if #clients == 0 then
    vim.notify("Ningún servidor LSP soporta renombrar aquí", vim.log.levels.WARN, { title = "Rename" })
    return
  end
  local client = clients[1]
  local cword = vim.fn.expand("<cword>")

  vim.ui.input({ prompt = "Renombrar a: ", default = cword }, function(new_name)
    if not new_name or new_name == "" or new_name == cword then
      return
    end
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    params.newName = new_name
    client:request("textDocument/rename", params, function(err, result)
      vim.schedule(function()
        if err or not result then
          vim.notify(err and err.message or "El servidor no devolvió cambios", vim.log.levels.WARN, { title = "Rename" })
          return
        end
        local files = M.edit_files(result)
        if #files == 0 then
          vim.notify("Sin cambios", vim.log.levels.INFO, { title = "Rename" })
          return
        end
        local title = string.format("Renombrar '%s' → '%s' — %d archivo(s)", cword, new_name, #files)
        M.confirm(files, title, client.offset_encoding, function(ok)
          if not ok then
            return
          end
          -- Popup final de confirmación (¿seguro?) con la pista de deshacer, tras revisar
          -- los cambios en el diálogo de preview.
          local sure = require("plugins.local.confirm").confirm(
            string.format("¿Aplicar el rename en %d archivo(s)?\nSe puede deshacer con <leader>lu", #files),
            "&Sí\n&No",
            1,
            { backdrop = true }
          )
          if sure ~= 1 then
            return
          end
          M.apply(result, client.offset_encoding)
          vim.notify(
            string.format("Renombrado en %d archivo(s).  :LspRenameUndo (o <leader>lu) para revertir", #files),
            vim.log.levels.INFO,
            { title = "Rename" }
          )
        end)
      end)
    end, bufnr)
  end)
end

-- Revierte el último rename restaurando los snapshots
function M.undo()
  if not snapshot then
    vim.notify("No hay ningún rename que revertir", vim.log.levels.INFO, { title = "Rename" })
    return
  end
  local n = 0
  for _, s in ipairs(snapshot) do
    if api.nvim_buf_is_valid(s.buf) then
      api.nvim_buf_set_lines(s.buf, 0, -1, false, s.lines)
      write_buf(s.buf) -- persistir la reversión (en apply guardamos a disco)
      n = n + 1
    end
  end
  snapshot = nil
  vim.notify(string.format("Rename revertido en %d archivo(s)", n), vim.log.levels.INFO, { title = "Rename" })
end

api.nvim_create_user_command("LspRenameUndo", M.undo, { desc = "Revertir el último rename del LSP" })

return M
