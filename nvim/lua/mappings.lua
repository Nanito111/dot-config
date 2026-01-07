require "nvchad.mappings"

-- Disable mappings
local nomap = vim.keymap.del

nomap("i", "<C-h>")
nomap("i", "<C-j>")
nomap("i", "<C-k>")
nomap("n", "<C-s>")
nomap("n", "<C-w>d")
nomap("n", "<C-w><C-d>")
nomap("n", "<leader>cm")
nomap("n", "<leader>gt")

-- Your mappings
local map = vim.keymap.set

map("i", "<C-j>", "<ENTER>", { desc = "Enter" })
map("i", "<C-k>", "<DEL>", { desc = "Delete" })

-------------------------------------------- conform --------------------------------------------
map({ "n", "v" }, "<leader>fm", function()
  require("conform").format {
    lsp_fallback = true,
    async = true,
  }
end, { desc = "Format Buffer" })
-------------------------------------------- conform --------------------------------------------

-- yank pasting
map("v", "p", "P", { desc = "Paste preserving yank" })
map("v", "P", "p", { desc = "Paste removing yank" })

-------------------------------------------- menu --------------------------------------------
-- Open Volt menu
-- Keyboard users
-- map({ "n", "v" }, "<C-t>", function()
--   require("menu").open "default"
-- end, { desc = "VoltMenu open (keyboard)" })
--
-- -- mouse users + nvimtree users!
-- map({ "n", "v" }, "<RightMouse>", function()
--   vim.cmd.exec '"normal! \\<RightMouse>"'
--
--   local options = vim.bo.ft == "NvimTree" and "nvimtree" or "default"
--   require("menu").open(options, { mouse = true })
-- end, { desc = "VoltMenu open (mouse)" })
-------------------------------------------- menu --------------------------------------------

-- better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

--text wrapping
map("n", "<leader>ww", function()
  vim.cmd.set "wrap"
end, { desc = "Wrap text" })
map("n", "<leader>wW", function()
  vim.cmd.set "nowrap"
end, { desc = "Unwrap text" })

-- todo-comments plugin
map("n", "<leader>ft", function()
  vim.cmd "Telescope todo-comments todo"
end, { desc = "telescope find TODO anotattions" })

-- find highlights groups
map("n", "<leader>fc", function()
  vim.cmd "Telescope highlights"
end, { desc = "telescope find colors (highlights groups)" })

-- find keymaps
map("n", "<leader>fk", function()
  vim.cmd "Telescope keymaps"
end, { desc = "telescope find keymaps" })

-- telescope vim options
map("n", "<leader>fv", function()
  vim.cmd "Telescope vim_options"
end, { desc = "telescope find vim options" })

-------------------------------------------- GIT --------------------------------------------
-- git blame
map("n", "gb", function()
  require("gitsigns").blame_line {
    full = false,
  }
end, { desc = "Git blame line" })
-- git blame full
map("n", "gB", function()
  require("gitsigns").blame_line {
    full = true,
  }
end, { desc = "Git blame line" })

-- git commits [telescope]
map("n", "<leader>gc", function()
  vim.cmd "Telescope git_commits"
end, { desc = "telescope git commits" })

-- git status [telescope]
map("n", "<leader>gs", function()
  vim.cmd "Telescope git_status"
end, { desc = "telescope git status" })

-- lazygit [nvterm]
map({ "n", "t" }, "<A-l>", function()
  require("nvchad.term").toggle {
    pos = "float",
    id = "lazygit",
    cmd = "lazygit && exit 0",
    float_opts = {
      row = 0,
      col = 0,
      width = 1,
      height = 0.95,
      border = "none",
    },
  }
end, { desc = "terminal toggle lazygit" })

-------------------------------------------- GIT --------------------------------------------

-------------------------------------------- LSP --------------------------------------------
-- hover
map("n", "K", function()
  vim.lsp.buf.hover {
    max_width = 80,
    max_height = 20,
  }
end, { desc = "LSP Show lsp info under cursor" })

-- diagnostic float
map("n", "F", function()
  vim.diagnostic.open_float {
    border = "rounded",
    max_width = 80,
  }
end, { desc = "LSP Show diagnostics from current line" })

-- find references [telescope]
map("n", "<leader>fr", function()
  vim.cmd "Telescope lsp_references"
end, { desc = "telescope find lsp references" })

-- find workspace diagnostics [telescope]
map("n", "<leader>da", function()
  vim.cmd "Telescope diagnostics"
end, { desc = "telescope find workspace diagnostics" })

-- find buffer diagnostics [telescope]
map("n", "<leader>db", function()
  vim.cmd "Telescope diagnostics bufnr=0"
end, { desc = "telescope find buffer diagnostics" })
-------------------------------------------- LSP --------------------------------------------
