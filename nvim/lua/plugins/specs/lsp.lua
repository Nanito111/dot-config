-- LSP: mason (instala binarios) + mason-lspconfig (auto-instala y auto-activa) +
-- nvim-lspconfig (configs base de cada servidor). Sobre Neovim 0.11+ los servidores
-- se activan con vim.lsp.enable y se ajustan con vim.lsp.config.
return {
  -- Gestor de binarios LSP / formatters / linters
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = {}, -- el borde lo pone 'winborder' (ver config.borders)
  },

  -- Puente mason <-> lspconfig + nvim-lspconfig
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
    },
    config = function()
      -- Servidores a instalar automáticamente. Añade los que necesites (sus
      -- binarios los baja mason): "pyright", "ts_ls", "bashls", "jsonls",
      -- "gopls", "rust_analyzer", "clangd", ...
      local ensure_installed = { "lua_ls" }

      require("mason-lspconfig").setup({
        ensure_installed = ensure_installed,
        automatic_enable = true, -- activa (vim.lsp.enable) los servidores instalados
      })

      -- :LspLog — abrir el log del cliente LSP en una pestaña nueva (al final)
      vim.api.nvim_create_user_command("LspLog", function()
        vim.cmd("tabedit " .. vim.fn.fnameescape(vim.lsp.get_log_path()))
        vim.cmd("normal! G") -- saltar a lo más reciente
      end, { desc = "Abrir el log del LSP" })

      -- Capacidades de completado de blink para todos los servidores
      local ok, blink = pcall(require, "blink.cmp")
      if ok then
        vim.lsp.config("*", { capabilities = blink.get_lsp_capabilities() })
      end

      -- Ajustes específicos por servidor (se fusionan con la config base de lspconfig)
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } }, -- reconocer el global vim
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })

      -- tailwindcss: al adjuntarse registra file-watchers dinámicos
      -- (workspace/didChangeWatchedFiles) sobre un glob enorme. Neovim monta esos
      -- watchers recorriendo TODO el árbol (incluido node_modules) de forma síncrona en
      -- el hilo de UI -> congela el editor unos segundos al abrir un .ts/.tsx. Al negar
      -- dynamicRegistration, el servidor no pide esos watchers y arranca sin bloquear.
      -- (Contrapartida: no auto-detecta cambios en tailwind.config vía watcher; basta
      -- reabrir el archivo o :LspRestart tras tocar la config de Tailwind.)
      vim.lsp.config("tailwindcss", {
        capabilities = {
          workspace = {
            didChangeWatchedFiles = { dynamicRegistration = false },
          },
        },
      })

      -- Diagnósticos (UI) y keymaps del LspAttach viven en config.lspkeys, que SÍ es
      -- recargable con :ReloadConfig (este spec está en SKIP_RELOAD).
    end,
  },
}
