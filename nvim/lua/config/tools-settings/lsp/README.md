# lsp-config

Ajustes locales por servidor LSP, **ignorados por git** (salvo este README).
Un `.lua` por nombre de servidor que devuelve una tabla; se fusiona en `vim.lsp.config`.

Ej.: `lua_ls.lua`. Lo carga `lua/config/lsp_local.lua`.
