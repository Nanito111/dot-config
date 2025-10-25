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

-- vim.api.nvim_create_autocmd("ModeChanged", {
--   callback = function()
--     if vim.fn.mode() == "n" then
--       vim.api.nvim_get_hl_by_name "hola"
--     end
--   end,
-- })

-- Fold Stuff
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

function _G.my_foldtext()
  -- inicio y fin del pliegue
  local start = vim.v.foldstart
  local finish = vim.v.foldend
  local count = finish - start + 1

  -- obtener la primera línea del pliegue
  local line = vim.api.nvim_buf_get_lines(0, start - 1, start, false)[1] or ""
  line = vim.trim(line)

  -- limitar longitud y añadir indicador de pliegue
  if #line > 80 then
    line = line:sub(1, 77) .. "..."
  end

  -- construir texto final
  return string.format("%s  [%d lines]", line, count)
end

vim.opt.foldtext = "v:lua.my_foldtext()"
vim.opt.fillchars = { fold = " ", foldopen = "▼", foldclose = "▶", foldsep = "│" }
vim.wo.foldcolumn = "auto:5"
