-- Linters y formatters (usan los binarios instalados con :Mason):
--   • conform.nvim -> formatear (al guardar, con toggle en editor.format_on_save)
--   • nvim-lint    -> linters que no son LSP
-- config.tools arma las tablas por filetype según lo instalado en Mason; la fachada
-- config.format expone format()/toggle() y el estado del panel.
return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>lf",
        function()
          require("config.format").format()
        end,
        desc = "Formatear buffer",
      },
      {
        "<leader>lF",
        function()
          require("config.format").toggle()
        end,
        desc = "Formatear al guardar (toggle)",
      },
    },
    opts = {
      -- formatters_by_ft lo arma config.tools según lo instalado en Mason (no se lista aquí)
      -- al guardar solo si el ajuste está activo; si no hay formateador propio, usa el del LSP
      format_on_save = function()
        if not require("config.format").on_save_enabled() then
          return nil
        end
        return { timeout_ms = 2000, lsp_format = "fallback" }
      end,
    },
    config = function(_, opts)
      require("conform").setup(opts)
      local tools = require("config.tools")
      tools.rebuild() -- llena formatters_by_ft desde Mason
      tools.watch() -- y lo reconstruye al instalar/quitar herramientas
    end,
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      -- linters_by_ft lo arma config.tools según lo instalado en Mason
      local tools = require("config.tools")
      tools.rebuild()
      tools.watch()
      local grp = vim.api.nvim_create_augroup("NvimLint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group = grp,
        callback = function()
          require("lint").try_lint() -- no falla si el binario/config no está
        end,
      })
    end,
  },
}
