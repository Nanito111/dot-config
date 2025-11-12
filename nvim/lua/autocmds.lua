require "nvchad.autocmds"

-- indenting for gdscript
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "gdscript", "cs" },
  callback = function()
    vim.opt.tabstop = 4
    vim.opt.softtabstop = 4
    vim.opt.expandtab = false
  end,
})
-- open file with folds open
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    vim.opt.foldlevel = 99
  end,
})

-- use LSP folding if client supports it
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)

    if client:supports_method "textDocument/foldingRange" then
      local win = vim.api.nvim_get_current_win()
      vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
    end
  end,
})

-- autoclose terms windows
-- this prevent showing [Process exited {status_code}] message
vim.api.nvim_create_autocmd("TermClose", {
  pattern = "*",
  callback = function(args)
    vim.cmd("bdelete! " .. args.buf)
  end,
})
