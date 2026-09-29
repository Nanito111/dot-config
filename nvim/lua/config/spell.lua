-- Gestor de diccionarios de ortografía (spell): un selector que lista idiomas, marca cuáles
-- están instalados y, al pulsar ⏎ sobre uno, lo descarga (del mirror de Vim) SIN cerrar el
-- selector, refrescando su estado. Los .spl van al dir de spell del usuario.
local api = vim.api
local M = {}

-- Idiomas del mirror de spell de Vim (código -> nombre en español).
local LANGS = {
  { "es", "Español" },
  { "en", "Inglés" },
  { "pt", "Portugués" },
  { "fr", "Francés" },
  { "de", "Alemán" },
  { "it", "Italiano" },
  { "ca", "Catalán" },
  { "gl", "Gallego" },
  { "nl", "Neerlandés" },
  { "ru", "Ruso" },
  { "uk", "Ucraniano" },
  { "pl", "Polaco" },
  { "cs", "Checo" },
  { "sk", "Eslovaco" },
  { "sv", "Sueco" },
  { "da", "Danés" },
  { "nb", "Noruego (Bokmål)" },
  { "nn", "Noruego (Nynorsk)" },
  { "ro", "Rumano" },
  { "hu", "Húngaro" },
  { "el", "Griego" },
  { "hr", "Croata" },
  { "sl", "Esloveno" },
  { "lt", "Lituano" },
  { "lv", "Letón" },
  { "ga", "Irlandés" },
  { "gd", "Gaélico escocés" },
  { "cy", "Galés" },
  { "af", "Afrikáans" },
  { "id", "Indonesio" },
  { "la", "Latín" },
  { "he", "Hebreo" },
  { "yi", "Yidis" },
  { "eo", "Esperanto" },
}

local BASE = "https://ftp.nluug.nl/pub/vim/runtime/spell/"

local function spell_dir()
  return vim.fn.stdpath("data") .. "/site/spell"
end

-- ¿el diccionario está instalado? (en cualquier dir de spell del runtime)
local function installed(code)
  if vim.fn.globpath(vim.o.runtimepath, "spell/" .. code .. ".*.spl") ~= "" then
    return true
  end
  return vim.fn.filereadable(spell_dir() .. "/" .. code .. ".utf-8.spl") == 1
end

-- Descarga <code>.utf-8.spl (y su .sug si existe) al dir de spell del usuario, en segundo
-- plano. Llama a on_done(ok) al terminar.
local function install(code, on_done)
  if vim.fn.executable("curl") == 0 then
    vim.notify("curl no está en el PATH", vim.log.levels.ERROR, { title = "Spell" })
    return on_done and on_done(false)
  end
  local dir = spell_dir()
  vim.fn.mkdir(dir, "p")
  local spl = code .. ".utf-8.spl"
  vim.system(
    { "curl", "-fsSL", "-o", dir .. "/" .. spl, BASE .. spl },
    {},
    vim.schedule_wrap(function(r)
      if r.code == 0 then
        -- archivo de sugerencias (opcional; si no existe, no pasa nada)
        local sug = code .. ".utf-8.sug"
        vim.system({ "curl", "-fsSL", "-o", dir .. "/" .. sug, BASE .. sug }, {}, function() end)
        vim.notify("Diccionario instalado: " .. code, vim.log.levels.INFO, { title = "Spell" })
      else
        vim.notify("No se pudo instalar '" .. code .. "'", vim.log.levels.WARN, { title = "Spell" })
      end
      if on_done then
        on_done(r.code == 0)
      end
    end)
  )
end

-- Construye las líneas del selector (nombre, código y estado) + el mapa display -> código.
local function build()
  local items, map = {}, {}
  for _, l in ipairs(LANGS) do
    local code, name = l[1], l[2]
    local mark = installed(code) and "\u{f00c} instalado" or "\u{f0159} instalar"
    local disp = string.format("%-22s  %s", name .. " (" .. code .. ")", mark)
    items[#items + 1] = disp
    map[disp] = code
  end
  return items, map
end

-- Abre el selector de diccionarios. ⏎ instala el resaltado y refresca sin cerrar.
function M.pick()
  local items, map = build()
  require("plugins.local.picker").pick({
    title = "Diccionarios de ortografía",
    items = items,
    backdrop = true,
    footer = "⏎ instalar · Esc cerrar",
    keymaps = {
      ["<CR>"] = function(ctx)
        local code = map[ctx.item() or ""]
        if not code then
          return
        end
        if installed(code) then
          vim.notify("'" .. code .. "' ya está instalado", vim.log.levels.INFO, { title = "Spell" })
          return
        end
        vim.notify("Instalando '" .. code .. "'…", vim.log.levels.INFO, { title = "Spell" })
        install(code, function()
          local new_items, new_map = build()
          map = new_map
          ctx.set_items(new_items) -- refresca el estado sin cerrar el selector
        end)
      end,
    },
  })
end

return M
