require "nvchad.options"

vim.opt.wrap = false
vim.opt.shiftwidth = 0
vim.opt.scrolloff = 15
vim.opt.list = true
vim.opt.listchars = { tab = "> ", trail = "·" }

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

vim.o.cursorlineopt = "both"
vim.opt.guicursor =
  "n-v-c:block-Cursor/lCursor,i-ci-ve:block-blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,r-cr:hor20,o:hor50"

-- Folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = ""
vim.opt.fillchars = { eob = " ", fold = " ", foldopen = "▼", foldclose = "▶", foldsep = "│" }
vim.opt.foldcolumn = "auto:5"
vim.opt.foldlevelstart = 99
