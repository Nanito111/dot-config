-- Ventana de quickfix / location list (incluye la lista de diagnósticos de
-- <leader>dq). Aquí <Tab>/<S-Tab> NO deben cambiar de buffer del workspace; la
-- lista se recorre con j/k y se salta con <CR>. Mapeos locales al buffer que
-- anulan los globales de cicleo de buffers.
vim.keymap.set("n", "<Tab>", "<Nop>", { buffer = true, silent = true, desc = "(sin cicleo de buffers en la lista)" })
vim.keymap.set("n", "<S-Tab>", "<Nop>", { buffer = true, silent = true, desc = "(sin cicleo de buffers en la lista)" })
