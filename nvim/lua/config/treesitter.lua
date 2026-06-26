-- Resaltado con Treesitter nativo (sin nvim-treesitter): usamos los parsers y
-- queries que trae Neovim de fábrica (coherentes entre sí). Neovim 0.12 incluye
-- parsers para c, lua, markdown, markdown_inline, query, vim y vimdoc, y de hecho
-- arranca el resaltado solo en esos filetypes; este autocmd lo hace explícito y
-- cubre cualquier otro filetype que tenga parser en runtimepath. Si no hay parser,
-- se omite en silencio (pcall) y se usa el resaltado clásico por regex.
--
-- NOTA: no usamos nvim-treesitter porque su rama master es incompatible con la API
-- de directivas de Neovim 0.12 (rompía el markdown) y su rama main requiere el CLI
-- `tree-sitter` y reconstruir todos los parsers. El set nativo es a prueba de balas.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("Treesitter", { clear = true }),
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match) or args.match
    pcall(vim.treesitter.start, args.buf, lang)
  end,
})
