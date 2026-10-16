-- Gestor de diccionarios de ortografía (spell): un selector que lista idiomas, marca cuáles
-- están instalados y, al pulsar ⏎ sobre uno, lo descarga (del mirror de Vim) SIN cerrar el
-- selector, refrescando su estado. Los .spl van al dir de spell del usuario.
local api = vim.api
local M = {}

-- Idiomas del mirror de spell de Vim (código -> nombre en español).
local LANGS = {
  { "es", "Spanish" },
  { "en", "English" },
  { "pt", "Portuguese" },
  { "fr", "French" },
  { "de", "German" },
  { "it", "Italian" },
  { "ca", "Catalan" },
  { "gl", "Galician" },
  { "nl", "Dutch" },
  { "ru", "Russian" },
  { "uk", "Ukrainian" },
  { "pl", "Polish" },
  { "cs", "Czech" },
  { "sk", "Slovak" },
  { "sv", "Swedish" },
  { "da", "Danish" },
  { "nb", "Norwegian (Bokmål)" },
  { "nn", "Norwegian (Nynorsk)" },
  { "ro", "Romanian" },
  { "hu", "Hungarian" },
  { "el", "Greek" },
  { "hr", "Croatian" },
  { "sl", "Slovenian" },
  { "lt", "Lithuanian" },
  { "lv", "Latvian" },
  { "ga", "Irish" },
  { "gd", "Scottish Gaelic" },
  { "cy", "Welsh" },
  { "af", "Afrikaans" },
  { "id", "Indonesian" },
  { "la", "Latin" },
  { "he", "Hebrew" },
  { "yi", "Yiddish" },
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
    vim.notify("curl is not in PATH", vim.log.levels.ERROR, { title = "Spell" })
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
        vim.notify("Dictionary installed: " .. code, vim.log.levels.INFO, { title = "Spell" })
      else
        vim.notify("Could not install '" .. code .. "'", vim.log.levels.WARN, { title = "Spell" })
      end
      if on_done then
        on_done(r.code == 0)
      end
    end)
  )
end

-- Construye las líneas del selector (nombre, código, estado y si está activo en markdown)
-- + el mapa display -> código.
local function build()
  local active = tostring(require("config.winopts").get_md_spell())
  local act = {}
  for c in active:gmatch("[^,]+") do -- "es,en" -> {es, en}
    act[c] = true
  end
  local items, map = {}, {}
  for _, l in ipairs(LANGS) do
    local code, name = l[1], l[2]
    local state = installed(code) and "\u{f00c} installed" or "\u{f019} install"
    local disp = string.format("%-24s %s", name .. " (" .. code .. ")", state)
    if act[code] then
      disp = disp .. "  \u{2190} active in Markdown"
    end
    items[#items + 1] = disp
    map[disp] = code
  end
  return items, map
end

-- Abre el selector de diccionarios. ⏎ instala el resaltado y refresca sin cerrar.
function M.pick()
  local items, map = build()
  require("plugins.local.picker").pick({
    title = "Spelling dictionaries",
    items = items,
    backdrop = true,
    footer = "⏎ install · C-a apply in Markdown · Esc close",
    keymaps = {
      ["<CR>"] = function(ctx)
        local code = map[ctx.item() or ""]
        if not code then
          return
        end
        if installed(code) then
          vim.notify("'" .. code .. "' is already installed", vim.log.levels.INFO, { title = "Spell" })
          return
        end
        vim.notify("Installing '" .. code .. "'…", vim.log.levels.INFO, { title = "Spell" })
        install(code, function()
          local new_items, new_map = build()
          map = new_map
          ctx.set_items(new_items) -- refresca el estado sin cerrar el selector
        end)
      end,
      -- aplicar como corrector de Markdown (instala antes si hace falta)
      ["<C-a>"] = function(ctx)
        local code = map[ctx.item() or ""]
        if not code then
          return
        end
        local function apply()
          require("config.winopts").set_md_spell(code)
          vim.notify("Markdown spell checker: " .. code, vim.log.levels.INFO, { title = "Spell" })
          local ni, nm = build()
          map = nm
          ctx.set_items(ni)
        end
        if installed(code) then
          apply()
        else
          vim.notify("Installing '" .. code .. "' to apply it…", vim.log.levels.INFO, { title = "Spell" })
          install(code, function(ok)
            if ok then
              apply()
            end
          end)
        end
      end,
    },
  })
end

return M
