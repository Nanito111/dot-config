require "nvchad.options"

vim.cmd.set "nowrap"
vim.cmd.set "shiftwidth=0"
vim.opt.scrolloff = 15

local listchars = "tab:\\ \\ ,trail:·"
vim.cmd.set("listchars=" .. listchars)
vim.cmd.set "list"

-- AutoFormating Toggle
vim.api.nvim_create_user_command("FormatDisable", function(args)
  if args.bang then
    -- FormatDisable! will disable formatting just for this buffer
    vim.b.disable_autoformat = true
  else
    vim.g.disable_autoformat = true
  end
end, {
  desc = "Disable autoformat-on-save",
  bang = true,
})

vim.api.nvim_create_user_command("FormatEnable", function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
end, {
  desc = "Re-enable autoformat-on-save",
})

-- Indentation by Filetype
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gdscript",
  callback = function()
    vim.opt.tabstop = 4
    vim.opt.softtabstop = 4
    vim.cmd.set "noexpandtab"
    vim.cmd.set("listchars=eol:↴," .. listchars)
  end,
})

vim.o.cursorlineopt = "both"
vim.cmd.set "guicursor=n-v-c:block-Cursor/lCursor,i-ci-ve:block-blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,r-cr:hor20,o:hor50"

-- Folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = ""
vim.opt.fillchars = { eob = " ", fold = " ", foldopen = "▼", foldclose = "▶", foldsep = "│" }
vim.wo.foldcolumn = "auto:5"
vim.opt.foldlevelstart = 99
