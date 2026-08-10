-- Único punto de acceso a la API de mason-registry (poco documentada y reorganizada en Mason
-- 2.0): si upstream cambia, se arregla aquí. Expone la lista de instalados, los disponibles,
-- instalar/actualizar/desinstalar con progreso en vivo, y un hook de "algo cambió" para que la
-- vista se re-renderice.
local M = {}

local function registry()
  local ok, reg = pcall(require, "mason-registry")
  return ok and reg or nil
end
M.registry = registry

-- Operaciones en curso: name -> { pkg, action, state, line }. La vista las pinta con spinner.
M.in_progress = {}

-- La vista instala aquí su "re-renderízate" (throttled por el spinner).
local on_change = function() end
function M.set_on_change(fn)
  on_change = fn or function() end
end

-- ── Spinner global (mientras haya algo en curso) ───────────────────
local FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spin_idx, spin_timer = 1, nil
local function stop_spinner()
  if spin_timer then
    spin_timer:stop()
    spin_timer:close()
    spin_timer = nil
  end
end
local function ensure_spinner()
  if spin_timer then
    return
  end
  spin_timer = vim.uv.new_timer()
  spin_timer:start(80, 80, vim.schedule_wrap(function()
    spin_idx = spin_idx % #FRAMES + 1
    if next(M.in_progress) then
      on_change()
    else
      stop_spinner()
    end
  end))
end
function M.spinner()
  return FRAMES[spin_idx]
end

-- ── Consultas ──────────────────────────────────────────────────────
-- Instalados, con versión, categoría y si hay una versión más nueva.
function M.installed()
  local reg = registry()
  if not reg then
    return {}
  end
  local list = {}
  for _, pkg in ipairs(reg.get_installed_packages()) do
    local oki, iv = pcall(pkg.get_installed_version, pkg)
    local okl, lv = pcall(pkg.get_latest_version, pkg)
    list[#list + 1] = {
      name = pkg.name,
      pkg = pkg,
      version = oki and iv or nil,
      outdated = oki and okl and iv ~= lv,
      category = (pkg.spec.categories or {})[1] or "Otros",
    }
  end
  table.sort(list, function(a, b)
    return a.name < b.name
  end)
  return list
end

-- Nombres NO instalados (para el picker de "instalar nuevo").
function M.available()
  local reg = registry()
  if not reg then
    return {}
  end
  local out = {}
  for _, pkg in ipairs(reg.get_all_packages()) do
    if not pkg:is_installed() then
      out[#out + 1] = pkg.name
    end
  end
  table.sort(out)
  return out
end

-- Catálogo de NO instalados con metadatos (para filtrar el picker por categoría/lenguaje).
function M.catalog()
  local reg = registry()
  if not reg then
    return {}
  end
  local out = {}
  for _, pkg in ipairs(reg.get_all_packages()) do
    if not pkg:is_installed() then
      local s = pkg.spec or {}
      out[#out + 1] = { name = pkg.name, categories = s.categories or {}, languages = s.languages or {} }
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

function M.get(name)
  local reg = registry()
  if not reg then
    return nil
  end
  local ok, pkg = pcall(reg.get_package, name)
  return ok and pkg or nil
end

-- ── Acciones (con progreso en vivo) ────────────────────────────────
local function track(pkg, action, handle)
  local st = { pkg = pkg, action = action, state = "QUEUED", line = "", spawn = "" }
  M.in_progress[pkg.name] = st
  ensure_spinner()
  pcall(function()
    handle:on("state:change", function(new)
      st.state = new
    end)
    -- última línea de salida NO vacía (como la UI oficial: short_tailed_output)
    local function out(chunk)
      for _, line in ipairs(vim.split(chunk or "", "\n")) do
        if not line:match("^%s*$") then
          st.line = line:gsub("^%s+", ""):gsub("%s+$", "")
        end
      end
    end
    handle:on("stdout", out)
    handle:on("stderr", out)
    -- comando en curso (npm/pip/cargo…), como latest_spawn de mason
    handle:on("spawn_handles:change", function()
      local ok, sp = pcall(function()
        return handle:peek_spawn_handle():map(tostring):or_else(nil)
      end)
      st.spawn = (ok and sp) and tostring(sp):gsub("\n", " ") or st.spawn
    end)
  end)
  on_change()
end

-- Instalar (o actualizar: mason reinstala a la última versión).
function M.install(name)
  local pkg = M.get(name)
  if not pkg or pkg:is_installing() then
    return
  end
  local handle = pkg:install(nil, function(success, err)
    M.in_progress[name] = nil
    vim.schedule(function()
      if success then
        vim.notify(name .. " instalado", vim.log.levels.INFO, { title = "Mason" })
      else
        vim.notify("Falló instalar " .. name .. "\n" .. tostring(err), vim.log.levels.ERROR, { title = "Mason" })
      end
      on_change()
    end)
  end)
  track(pkg, "install", handle)
end

function M.update(pkg)
  M.install(pkg.name)
end

function M.uninstall(pkg)
  pkg:uninstall(nil, function(success, err)
    vim.schedule(function()
      if success ~= false then
        vim.notify(pkg.name .. " desinstalado", vim.log.levels.INFO, { title = "Mason" })
      else
        vim.notify("Falló desinstalar " .. pkg.name .. "\n" .. tostring(err), vim.log.levels.ERROR, { title = "Mason" })
      end
      on_change()
    end)
  end)
end

-- Suscribir a los eventos del registro: refrescar aunque la acción venga de fuera (:MasonInstall).
local subscribed = false
function M.subscribe()
  if subscribed then
    return
  end
  local reg = registry()
  if not reg then
    return
  end
  subscribed = true
  for _, ev in ipairs({ "package:install:success", "package:install:failed", "package:uninstall:success" }) do
    pcall(function()
      reg:on(ev, vim.schedule_wrap(function()
        on_change()
      end))
    end)
  end
end

return M
