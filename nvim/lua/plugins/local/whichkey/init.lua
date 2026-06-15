-- which-key desde cero (plugin-free): al pulsar un prefijo (líder, g, z, <C-w>)
-- muestra las combinaciones disponibles y resuelve la secuencia tecla a tecla.
-- Datos de prefijos integrados en builtin.lua; popup/lectura de teclas en popup.lua.
local api = vim.api
local BUILTIN = require("plugins.local.whichkey.builtin")
local popup = require("plugins.local.whichkey.popup")

local M = {}

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

    local ch = popup.read_key(seq, build_entries(seq, longer), first)
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
