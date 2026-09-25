-- clippy/chatter: qué dice la mascota. Frases fijas, frase contextual (según archivo/estado)
-- y el "nivel de charla" configurable (probabilidad de comentar). Sin estado mutable.
local api = vim.api
local M = {}

M.GREET = "¡Hola! Soy Clippy, tu asistente. Andaré por aquí."
M.PRAISE = { "¡Guardado! 💾", "Buen trabajo, sigue así ✨", "Todo en orden." }
M.FLEE = {
  "¡Uy, perdón! Te dejo trabajar.",
  "Me quito de en medio.",
  "¡Ahí voy, que no te tapo!",
  "Perdona, no quería estorbar.",
  "Mejor me corro para allá.",
  "¡Todo tuyo el código!",
}
M.WS_LINES = {
  WorkspaceNew = {
    "¡Workspace '%s' listo! A estrenarlo.",
    "Nuevo espacio '%s'. Empezamos de cero.",
    "Creaste '%s'. Me mudo contigo.",
  },
  WorkspaceRenamed = {
    "Ahora esto se llama '%s'. Anotado.",
    "'%s', buen nombre.",
  },
  WorkspaceSwitch = {
    "Te moviste a '%s'. Te sigo.",
    "Cambiando de aires: '%s'.",
    "En '%s' ahora. ¿Qué toca?",
  },
  WorkspaceMoved = {
    "Reordenando workspaces, muy prolijo.",
    "'%s' cambió de lugar. Ordenadito.",
  },
}

function M.pick(t)
  return t[math.random(#t)]
end

-- Nivel de charla (configurable): probabilidad de comentar una acción. "callado" = 0 (solo
-- mascota, sin frases). Se lee de settings en cada evento para reflejar cambios en caliente.
local CHATTER = { callado = 0, poco = 0.15, normal = 0.34, hablador = 0.7 }
function M.chatter_p()
  return CHATTER[require("config.settings").value("ui.clippy_chatter", "normal")] or 0.34
end
function M.talk_ok()
  return math.random() < M.chatter_p()
end

-- Qué corre en un buffer de terminal: mira nombre del buffer + título del terminal
-- (que el programa actualiza) + el nombre que le pusimos nosotros.
local function term_kind(buf)
  if vim.bo[buf].buftype ~= "terminal" then
    return nil
  end
  local hay = (api.nvim_buf_get_name(buf) .. " " .. (vim.b[buf].term_title or "") .. " " .. (vim.b[buf].term_name or ""))
    :lower()
  if hay:find("lazygit") then
    return "lazygit"
  elseif hay:find("claude") then
    return "claude"
  end
  return "terminal"
end

-- Frase al azar, tirando de lo que está pasando ahora mismo (archivo, lenguaje, posición,
-- cambios sin guardar, avisos del LSP, hora) para que parezca al tanto.
function M.remark()
  local buf = api.nvim_get_current_buf()
  local tk = term_kind(buf)
  if tk == "lazygit" then
    return M.pick({
      "Veo que andas en lazygit. Cuidado con ese force-push.",
      "Commiteando, ¿eh? Que no se te escape nada.",
      "lazygit: donde los conflictos van a morir.",
      "Un buen stage vale más que mil disculpas.",
    })
  elseif tk == "claude" then
    return M.pick({
      "¿Charlando con Claude? Salúdalo de mi parte.",
      "Delegando en la IA, muy siglo XXI.",
      "Yo superviso mientras Claude teclea.",
      "Dos asistentes en pantalla; qué lujo.",
    })
  elseif tk == "terminal" then
    return M.pick({
      "Una terminal abierta. A teclear se ha dicho.",
      "Comandos van, comandos vienen.",
      "¿Compilando algo? Cruzo los dedos.",
      "Ojo con ese rm -rf, que yo miro.",
    })
  end
  local out = {
    "Deambular es mi cardio.",
    "No hago nada útil, pero te hago compañía.",
    "A veces solo quiero pasear por el buffer.",
    "Bonito tema el que tienes puesto.",
  }
  local function add(s)
    out[#out + 1] = s
  end
  local name = vim.fn.expand("%:t")
  local ft = vim.bo[buf].filetype
  local lines = api.nvim_buf_line_count(buf)
  local row = (api.nvim_win_get_cursor(0) or { 1 })[1]
  if vim.bo[buf].modified then
    add(("Tienes cambios sin guardar en %s. Solo lo menciono…"):format(name ~= "" and name or "este buffer"))
  end
  if name ~= "" then
    add(("Andas con %s, ya veo."):format(name))
  else
    add("Un buffer sin nombre; lienzo en blanco.")
  end
  if ft ~= "" then
    add(("Veo que escribes %s. Observando..."):format(ft))
  end
  if lines > 500 then
    add(("%d líneas… esto ... spaguetti?."):format(lines))
  elseif lines <= 5 then
    add("Archivo cortito, se agradece.")
  end
  if row <= 1 then
    add("Arrancando desde arriba, clásico.")
  elseif row >= lines - 1 then
    add("Ya casi tocas el final del archivo.")
  else
    add(("Vas por la línea %d de %d."):format(row, lines))
  end
  local nd = 0
  pcall(function()
    nd = #vim.diagnostic.get(buf)
  end)
  if nd > 0 then
    add(("Cuento %d aviso%s del LSP por ahí. Tú sabrás."):format(nd, nd == 1 and "" or "s"))
  end
  local h = tonumber(os.date("%H")) or 12
  if h < 6 then
    add("¿Programando de madrugada? Yo también trasnocho.")
  elseif h < 12 then
    add("Buen día para escribir código.")
  elseif h < 20 then
    add("La tarde rinde, sigue así.")
  else
    add("Ya es de noche; no te desveles mucho.")
  end
  return out[math.random(#out)]
end

return M
