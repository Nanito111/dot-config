-- Aviso de actualizaciones de herramientas LSP/format (mason) al iniciar.
--
-- Los PLUGINS los gestiona el checker periódico de lazy (init.lua: checker.enabled),
-- que avisa solo al arrancar. Mason no tiene checker propio, así que lo comprobamos
-- aquí: diferido tras el arranque (hace red: refresco del registro), sin bloquear.

local function check_mason()
  local ok, registry = pcall(require, "mason-registry")
  if not ok then
    return
  end
  registry.refresh(vim.schedule_wrap(function()
    local outdated = {}
    for _, pkg in ipairs(registry.get_installed_packages()) do
      local okc, cur = pcall(pkg.get_installed_version, pkg)
      local okl, latest = pcall(pkg.get_latest_version, pkg)
      if okc and okl and cur and latest and cur ~= latest then
        outdated[#outdated + 1] = pkg.name
      end
    end
    if #outdated > 0 then
      vim.notify(
        #outdated .. " herramienta(s) con actualización  ·  :Mason\n(" .. table.concat(outdated, ", ") .. ")",
        vim.log.levels.INFO,
        { title = "Mason" }
      )
    end
  end))
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("UpdatesCheck", { clear = true }),
  desc = "Comprobar actualizaciones de herramientas (mason) tras el arranque",
  callback = function()
    vim.defer_fn(function()
      pcall(check_mason)
    end, 2000)
  end,
})

return {}
