-- Un solo flotante "principal" a la vez: al reclamar uno nuevo se cierra el anterior, para
-- que no se apilen (abrir B cierra A). Lo usan los flotantes que PERSISTEN (terminal
-- flotante, popups, picker…); NO los toasts de notify, los tooltips ni los modales
-- bloqueantes (confirm/whichkey), que se gestionan solos.
local M = {}

local active -- entrada { close = fn } del flotante principal actual

-- Registra `entry` como el flotante principal y cierra el anterior (si es otro).
function M.claim(entry)
  local prev = active
  active = entry
  if prev and prev ~= entry and prev.close then
    pcall(prev.close)
  end
end

-- Suelta `entry` si sigue siendo el activo (lo llama el propio flotante al cerrarse).
function M.release(entry)
  if active == entry then
    active = nil
  end
end

return M
