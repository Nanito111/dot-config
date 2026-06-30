-- LSP: mason (instala binarios) + mason-lspconfig (auto-instala y auto-activa) +
-- nvim-lspconfig (configs base de cada servidor). Sobre Neovim 0.11+ los servidores
-- se activan con vim.lsp.enable y se ajustan con vim.lsp.config.
return {
  -- Gestor de binarios LSP / formatters / linters
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    opts = { ui = { border = "rounded" } },
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

      -- ── Diagnósticos (UI) ──────────────────────────────────────────
      vim.diagnostic.config({
        -- virtual_lines solo en la línea del cursor: muestra el mensaje completo
        -- en línea, debajo del código, sin llenar la pantalla. Sin virtual_text.
        virtual_lines = { current_line = true },
        virtual_text = false,
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "\u{f057}",
            [vim.diagnostic.severity.WARN] = "\u{f071}",
            [vim.diagnostic.severity.INFO] = "\u{f05a}",
            [vim.diagnostic.severity.HINT] = "\u{f0eb}",
          },
        },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = "rounded", source = true },
      })

      -- ── Keymaps al conectar un servidor a un buffer ────────────────
      -- Neovim 0.11+ ya trae por defecto grn (renombrar), gra (acción de código),
      -- grr (referencias), gri (implementación), gO (símbolos), K (hover) y
      -- <C-s> en inserción (ayuda de firma). Aquí añadimos el resto.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("LspAttach", { clear = true }),
        callback = function(args)
          local buf = args.buf
          local function map(lhs, fn, desc)
            vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc, silent = true })
          end
          map("gd", vim.lsp.buf.definition, "LSP: ir a definición")
          map("gD", vim.lsp.buf.declaration, "LSP: ir a declaración")
          -- K: hover en ventana flotante con borde redondeado (a juego con el resto)
          map("K", function()
            vim.lsp.buf.hover({ border = "rounded" })
          end, "LSP: hover (documentación)")
          map("<leader>lr", vim.lsp.buf.rename, "LSP: renombrar símbolo")
          map("<leader>la", vim.lsp.buf.code_action, "LSP: acciones de código")
          map("<leader>lf", function()
            vim.lsp.buf.format({ async = true })
          end, "LSP: formatear buffer")
          -- Los diagnósticos viven en su propio grupo global <leader>d* (config.keymaps)
        end,
      })
    end,
  },
}
