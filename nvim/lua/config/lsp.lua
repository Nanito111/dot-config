-- Servidores LSP POR TIPO DE ARCHIVO. Sobre Neovim 0.11 cada servidor instalado se activa
-- (vim.lsp.enable, vía mason-lspconfig) y se adjunta a los buffers cuyo filetype está en su
-- lista `filetypes`. Este módulo deja elegir, por lenguaje, qué servidores corren: desactivar
-- uno para un filetype equivale a quitar ese filetype de su config (vim.lsp.config reemplaza
-- la lista entera). Solo se persiste lo deshabilitado (vía config.settings); se reaplica al
-- arrancar y en :ReloadConfig. La tabla del panel (settings.lsp_table) consume este módulo.
local api = vim.api
local M = {}

local KEY = "lsp.disabled" -- { [server] = { [ft] = true } } (solo lo deshabilitado)

-- ── Overrides persistidos (overrides-only) ─────────────────────────
local disabled = nil -- cache; nil = aún no cargado
local function dis()
  if disabled == nil then
    disabled = vim.deepcopy(require("config.settings").value(KEY, {}))
  end
  return disabled
end

local function persist()
  for s, fts in pairs(disabled) do
    if next(fts) == nil then
      disabled[s] = nil -- no dejar servidores sin nada deshabilitado
    end
  end
  require("config.settings").record(KEY, disabled, {})
end

-- ── Servidores instalados y sus filetypes "de fábrica" ─────────────
-- Servidores que mason-lspconfig tiene instalados y activa (el set real que corre).
function M.installed()
  local ok, mlc = pcall(require, "mason-lspconfig")
  if not ok or not mlc.get_installed_servers then
    return {}
  end
  local list = vim.deepcopy(mlc.get_installed_servers())
  table.sort(list)
  return list
end

-- Filetypes PRÍSTINOS de un servidor: se leen del fichero fuente de lspconfig (lsp/<name>.lua)
-- con dofile, no de vim.lsp.config[name], porque en cuanto aplicamos un override la config viva
-- ya refleja la lista recortada (y tras :ReloadConfig seguiría recortada). El fichero fuente es
-- inmune a eso. Se cachea el resultado.
local default_cache = {}
function M.default_fts(name)
  if default_cache[name] then
    return default_cache[name]
  end
  local files = api.nvim_get_runtime_file("lsp/" .. name .. ".lua", false)
  local fts
  if files[1] then
    local ok, cfg = pcall(dofile, files[1])
    if ok and type(cfg) == "table" and type(cfg.filetypes) == "table" then
      fts = cfg.filetypes
    end
  end
  if not fts then -- respaldo: la config viva (puede venir ya recortada por un override nuestro)
    local c = vim.lsp.config[name]
    fts = (c and c.filetypes) or {}
  end
  default_cache[name] = fts
  return fts
end

-- ¿lspconfig ya cargó? (sus ficheros lsp/ están en el runtimepath). Sin eso no hay filetypes
-- de fábrica fiables, así que apply() se pospone hasta que el spec de lspconfig los tenga.
local function lspconfig_ready()
  return api.nvim_get_runtime_file("lsp/lua_ls.lua", false)[1] ~= nil
end

-- Fuerza la carga de nvim-lspconfig (que es lazy: carga al abrir un archivo de código) para que
-- sus ficheros lsp/ estén en el runtimepath. Se llama SOLO desde los puntos de entrada de la
-- tabla (acción interactiva); nunca desde apply(), para no romper la carga lazy en el arranque.
local function ensure_lspconfig()
  if not lspconfig_ready() then
    pcall(function()
      require("lazy").load({ plugins = { "nvim-lspconfig" } })
    end)
  end
end

-- ── Estado por (servidor, filetype) ────────────────────────────────
function M.is_enabled(name, ft)
  local d = dis()[name]
  return not (d and d[ft])
end

-- Filetypes efectivos de un servidor = los de fábrica menos los deshabilitados.
function M.effective_fts(name)
  local d = dis()[name]
  local out = {}
  for _, ft in ipairs(M.default_fts(name)) do
    if not (d and d[ft]) then
      out[#out + 1] = ft
    end
  end
  return out
end

-- ── Aplicación a vim.lsp.config ────────────────────────────────────
-- Reafirma la lista de filetypes de cada servidor instalado (o solo `only`). No reinicia
-- clientes: en el arranque/recarga los servidores (re)adjuntan solos; el reinicio en vivo lo
-- hace reconcile() tras un cambio interactivo.
function M.apply(only)
  if not lspconfig_ready() then
    return -- el spec de lspconfig llamará a apply() al cargar
  end
  for _, name in ipairs(M.installed()) do
    if only == nil or only == name then
      pcall(vim.lsp.config, name, { filetypes = M.effective_fts(name) })
    end
  end
end

-- Reajusta en caliente un servidor tras cambiar sus filetypes: si ya no sirve `ft`, lo
-- desadjunta de los buffers de ese tipo; luego deja que el autostart nativo re-evalúe los
-- buffers abiertos (vim.lsp.enable -> doautoall solo del grupo nvim.lsp.enable, sin tocar
-- ftplugins ni treesitter) para que se adjunte donde ahora sí corresponda.
local function reconcile(name, ft)
  if not vim.tbl_contains(M.effective_fts(name), ft) then
    for _, client in ipairs(vim.lsp.get_clients({ name = name })) do
      for buf in pairs(client.attached_buffers or {}) do
        if api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == ft then
          pcall(vim.lsp.buf_detach_client, buf, client.id)
        end
      end
    end
  end
  pcall(vim.lsp.enable, name, true)
end

-- ── Edición ────────────────────────────────────────────────────────
function M.set_enabled(name, ft, enabled)
  local d = dis()
  if enabled then
    if d[name] then
      d[name][ft] = nil
    end
  else
    d[name] = d[name] or {}
    d[name][ft] = true
  end
  persist()
  M.apply(name)
  reconcile(name, ft)
end

function M.toggle(name, ft)
  M.set_enabled(name, ft, not M.is_enabled(name, ft))
end

-- Reactiva todos los servidores de un filetype (quita sus deshabilitados)
function M.reset_ft(ft)
  local d = dis()
  local touched = {}
  for name, fts in pairs(d) do
    if fts[ft] then
      fts[ft] = nil
      touched[#touched + 1] = name
    end
  end
  persist()
  for _, name in ipairs(touched) do
    M.apply(name)
    reconcile(name, ft)
  end
end

-- ── Datos para la tabla ────────────────────────────────────────────
-- Servidores candidatos a un filetype, con su estado: { { name, enabled }, ... } (orden alfab.)
function M.servers_for_ft(ft)
  ensure_lspconfig()
  local out = {}
  for _, name in ipairs(M.installed()) do
    if vim.tbl_contains(M.default_fts(name), ft) then
      out[#out + 1] = { name = name, enabled = M.is_enabled(name, ft) }
    end
  end
  return out
end

-- Filas del nivel 1 (lenguajes): un filetype por fila, con cuántos servidores corren de los
-- candidatos y si tiene algo deshabilitado. Orden: primero los de varios servidores, luego alfab.
function M.rows()
  ensure_lspconfig()
  local by_ft = {}
  for _, name in ipairs(M.installed()) do
    for _, ft in ipairs(M.default_fts(name)) do
      by_ft[ft] = by_ft[ft] or {}
      by_ft[ft][#by_ft[ft] + 1] = name
    end
  end
  local rows = {}
  for ft, servers in pairs(by_ft) do
    table.sort(servers)
    local on, overridden = 0, false
    for _, name in ipairs(servers) do
      if M.is_enabled(name, ft) then
        on = on + 1
      else
        overridden = true
      end
    end
    rows[#rows + 1] = { ft = ft, servers = servers, total = #servers, enabled = on, overridden = overridden }
  end
  table.sort(rows, function(a, b)
    if a.total ~= b.total then
      return a.total > b.total
    end
    return a.ft < b.ft
  end)
  return rows
end

return M
