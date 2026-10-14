-- Sondeo de los linters (nvim-lint) para :LintInfo. nvim-lint descarta el stderr de los
-- linters que parsean stdout, así que los errores de configuración/entorno (p. ej. "No dialect
-- was specified" de sqlfluff) pasan desapercibidos: el linter aparece activo pero no avisa de
-- nada. Este módulo ejecuta el linter igual que nvim-lint capturando stdout/stderr/código y
-- detecta si falló al arrancar (vs. encontró problemas), para que :LintInfo lo muestre.
local api = vim.api
local M = {}

local function eval(x)
  if type(x) == "function" then
    local ok, r = pcall(x)
    return ok and r or nil
  end
  return x
end

-- Cuenta (async, vía cb) los diagnósticos que el parser PROPIO del linter saca de `output`.
-- Así se distingue "el linter corrió y encontró problemas" (válido) de "no pudo analizar"
-- (error de setup). En nvim-lint el parser casi siempre es una función (from_pattern/
-- from_errorformat la devuelven): se llama directa y en síncrono. Los raros parsers de tabla
-- (on_chunk/on_done) publican de forma asíncrona, por eso el resultado va por callback.
local function parse_count(linter, output, bufnr, cb)
  local parser = linter.parser
  if type(parser) == "function" then
    local ok, diags = pcall(parser, output or "", bufnr)
    return cb((ok and type(diags) == "table") and #diags or 0)
  end
  if type(parser) ~= "table" or type(parser.on_done) ~= "function" then
    return cb(0)
  end
  local called = false
  local function publish(diags)
    if called then
      return
    end
    called = true
    cb(diags and #diags or 0)
  end
  local ok = pcall(function()
    parser.on_chunk(output or "")
    parser.on_done(publish, bufnr, linter.cwd)
  end)
  if not ok then
    cb(0)
  end
end

-- Decide (async, vía cb) si el resultado es un problema de setup y devuelve su mensaje (o nil).
-- La salida de resultados puede ir por stdout (lo normal), stderr o ambos (linter.stream): se
-- parsea ESE stream; el contrario es donde suelen ir los errores. Solo es problema si salió con
-- código ≠ 0 y el parser no obtuvo ningún diagnóstico (si obtuvo, el linter funciona bien).
local function analyze(linter, res, bufnr, cb)
  if (res.code or 0) == 0 then
    return cb(nil) -- corrió bien (sin issues)
  end
  local stream = linter.stream or "stdout"
  local out, err = res.stdout or "", res.stderr or ""
  local data = stream == "stderr" and err or (stream == "both" and (out .. "\n" .. err) or out)
  local other = stream == "stderr" and out or err
  parse_count(linter, data, bufnr, function(ndiag)
    if ndiag > 0 then
      return cb(nil) -- encontró diagnósticos: el linter funciona
    end
    local msg = vim.trim(other)
    if msg == "" then
      msg = vim.trim(data)
    end
    if msg == "" then
      msg = "salió con código " .. tostring(res.code)
    end
    cb(msg)
  end)
end

-- Sondea un linter y llama a cb({ cmd, found, msg }) (msg = problema de setup, o nil). cb(nil)
-- si nvim-lint no está cargado. El análisis se hace en el bucle principal (vim.schedule),
-- porque el parser del linter puede tocar APIs de Neovim.
function M.probe(name, bufnr, cb)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not package.loaded["lint"] then
    return cb(nil)
  end
  local l = eval(require("lint").linters[name])
  if type(l) ~= "table" then
    return cb({ cmd = nil, found = false, msg = nil })
  end
  local cmd = eval(l.cmd)
  if not cmd then
    return cb({ cmd = nil, found = false, msg = nil })
  end
  if vim.fn.executable(cmd) ~= 1 then
    return cb({ cmd = cmd, found = false, msg = nil })
  end
  local args = {}
  for _, a in ipairs(l.args or {}) do
    args[#args + 1] = eval(a)
  end
  if not l.stdin and l.append_fname ~= false then
    args[#args + 1] = api.nvim_buf_get_name(bufnr)
  end
  local stdin
  if l.stdin then
    stdin = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") .. "\n"
  end
  vim.system(vim.list_extend({ cmd }, args), { text = true, stdin = stdin }, function(res)
    vim.schedule(function()
      analyze(l, res, bufnr, function(msg)
        cb({ cmd = cmd, found = true, msg = msg })
      end)
    end)
  end)
end

return M
