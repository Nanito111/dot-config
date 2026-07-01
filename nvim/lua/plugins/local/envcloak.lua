-- Ocultar valores en archivos .env (plugin-free): enmascara lo que va después del
-- '=' (los secretos) para no exponerlos al compartir pantalla. Usa extmarks con
-- virt_text en modo overlay (ámbito de buffer, mantiene la longitud). La línea bajo
-- el cursor se muestra en claro para poder leer/editar. Toggle con :EnvCloak.
local api = vim.api
local M = {}

local ns = api.nvim_create_namespace("env_cloak")
local MASK = "•"
local HL = "Comment" -- color tenue para la máscara
local enabled = true -- estado global (togglable)

-- ¿el buffer es un archivo .env (.env, .env.local, .env.production, .envrc, ...)?
local function is_env(buf)
  if not api.nvim_buf_is_valid(buf) then
    return false
  end
  local base = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ":t")
  return base == ".env" or base:match("^%.env%.") ~= nil or base:match("%.env$") ~= nil or base == ".envrc"
end

-- Coloca/actualiza las máscaras del buffer. Revela la línea `reveal` (1-based) para
-- poder editarla; -1 = no revelar ninguna.
local function apply(buf, reveal)
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not enabled or not is_env(buf) then
    return
  end
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    if i ~= reveal then -- no enmascarar la línea del cursor (para editarla)
      -- Prefijo: espacios + '#' opcional (para enmascarar TAMBIÉN variables
      -- comentadas) + espacios. Lo que sigue debe ser una asignación KEY=VALUE
      -- (con 'export' opcional); si no, es un comentario de prosa y se ignora.
      local prefix = line:match("^%s*#?%s*")
      local after = line:sub(#prefix + 1)
      if after:match("^export%s+[%w_%.]+%s*=") or after:match("^[%w_%.]+%s*=") then
        local eq = #prefix + after:find("=") -- posición (1-based) del '=' en la línea
        local rest = line:sub(eq + 1)
        local lead = #(rest:match("^%s*")) -- espacios tras el '='
        local val = vim.trim(rest)
        if val ~= "" then
          local start_col = eq + lead -- 0-based: el valor empieza en eq+lead
          api.nvim_buf_set_extmark(buf, ns, i - 1, start_col, {
            virt_text = { { string.rep(MASK, vim.fn.strdisplaywidth(val)), HL } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
            priority = 200,
          })
        end
      end
    end
  end
end

-- Refresca el buffer actual (revelando su línea de cursor)
local function refresh(buf)
  buf = buf or api.nvim_get_current_buf()
  local reveal = -1
  if api.nvim_get_current_buf() == buf then
    reveal = api.nvim_win_get_cursor(0)[1] -- mostrar en claro la línea del cursor
  end
  apply(buf, reveal)
end

-- Alterna el enmascarado (todos los .env abiertos)
function M.toggle()
  enabled = not enabled
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if is_env(buf) then
      apply(buf, api.nvim_get_current_buf() == buf and api.nvim_win_get_cursor(0)[1] or -1)
    end
  end
  vim.notify("Ocultar .env: " .. (enabled and "ON" or "OFF"), vim.log.levels.INFO, { title = "EnvCloak" })
end

-- ── Activación ─────────────────────────────────────────────────────
local group = api.nvim_create_augroup("EnvCloak", { clear = true })

api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter", "TextChanged", "TextChangedI" }, {
  group = group,
  desc = "Enmascarar valores en archivos .env",
  callback = function(ev)
    if is_env(ev.buf) then
      refresh(ev.buf)
    end
  end,
})

-- Revelar la línea bajo el cursor (y reenmascarar la anterior) al moverse
api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = group,
  desc = "Revelar la línea del cursor en archivos .env",
  callback = function(ev)
    if is_env(ev.buf) then
      refresh(ev.buf)
    end
  end,
})

api.nvim_create_user_command("EnvCloak", M.toggle, { desc = "Alternar el ocultado de valores en .env" })

-- Enmascarar los .env ya abiertos (arranque y :ReloadConfig)
for _, buf in ipairs(api.nvim_list_bufs()) do
  if api.nvim_buf_is_loaded(buf) and is_env(buf) then
    refresh(buf)
  end
end

return M
