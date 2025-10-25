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
