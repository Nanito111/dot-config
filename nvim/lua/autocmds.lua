require "nvchad.autocmds"

-- indenting for gdscript
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gdscript",
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
