# Neovim Configuration

A personal, Lua-based Neovim configuration with a **"plugin-free"** philosophy: most of
the UI (statusline, file explorer, git signs, which-key, dashboard, winbar, indentation
guides, floating terminals, notifications, etc.) is implemented as **custom local modules**
under `lua/plugins/local/`, without external plugins. Plugins are only used for the things
not worth rewriting: completion, LSP, and colorschemes.

---

## Requirements

### Required

| Requirement | Why | Notes |
|---|---|---|
| **Neovim ≥ 0.11** | Uses the modern LSP API (`vim.lsp.config`, `vim.lsp.enable`), `vim.diagnostic.jump`, `vim.uv`, etc. | Tested on **0.12**. Won't work properly on < 0.11. |
| **Git** | `lazy.nvim` clones/updates plugins; git signs, the statusline branch, and blame all shell out to `git`. | Must be on your `PATH`. |
| **A Nerd Font** | Icons in the statusline, explorer, winbar, diagnostics, indent module, etc. | Install a [Nerd Font](https://www.nerdfonts.com/) and enable it in your terminal. |
| **A true-color terminal** | The config uses `termguicolors` and per-theme palettes. | Most modern terminals support it. |
| **Mouse enabled** | Clickable statusline buttons (indent type / width) and window resizing. | `mouse=a` (the default). |
| **ripgrep (`rg`)** | Powers the file finder (`<leader>ff`) and content search (`<leader>fw`, `:Grep`). | Without `rg` those pickers warn and don't work. |

### Recommended / optional

| Requirement | Used for |
|---|---|
| **Node.js** | JS-based LSP servers installed by Mason (e.g. `ts_ls`, `tailwindcss`). Not needed if you only use `lua_ls`. |
| **`curl`/`wget`, `unzip`, `tar`** | Needed by **Mason** to download and install LSP binaries. |
| **A clipboard provider** | `clipboard=unnamedplus` needs one: `win32yank` (WSL), `wl-clipboard`/`xclip` (Linux), `pbcopy` (macOS). |
| **`lazygit`** | Floating git window: `:Lazygit` / `<M-g>`. |
| **`claude`** (CLI) | Floating window: `:Claude` / `<M-c>`. |
| **Rust / `cargo`** | Only if `blink.cmp` can't download its prebuilt binary; it falls back to the Lua matcher with a warning. |

---

## Plugins (installed automatically)

On first launch, **`lazy.nvim`** bootstraps itself and downloads everything else. No manual
steps required.

- **Completion:** [`blink.cmp`](https://github.com/saghen/blink.cmp) + `friendly-snippets`
- **LSP:** `mason.nvim`, `mason-lspconfig.nvim`, `nvim-lspconfig`
  - Default server: **`lua_ls`** (installed automatically). Add more in
    `lua/plugins/specs/lsp.lua` → `ensure_installed`.
- **Colorschemes:** `tokyonight`, `catppuccin`, `kanagawa`, `gruvbox`, `rose-pine`,
  `nightfox` (pick one with `<leader>ut`)
- **Extra:** [`duck.nvim`](https://github.com/tamton-aquib/duck.nvim) 🦆 (a pet, `<leader>p`)

Everything else (statusline, explorer, git, which-key, dashboard, winbar, indentation
guides, terminals, notifications, etc.) is **custom code** with no dependencies.

---

## Installation

```sh
# 1. Back up your current config (if any)
mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null

# 2. Clone this config into ~/.config/nvim
git clone <this-repo> ~/.config/nvim

# 3. Start Neovim: lazy.nvim installs itself and downloads the plugins;
#    Mason installs lua_ls. Let it finish.
nvim

# 4. Verify everything is healthy — inside Neovim:
:checkhealth
```

---

## Handy commands & keymaps

| Keymap / command | Action |
|---|---|
| `<space>` | which-key menu (shows all groups) |
| `<leader>ff` / `fw` / `fb` | Find files / content / buffers |
| `<leader>e` | File explorer |
| `<leader>l…` | LSP group (references, definition, symbols, rename…) |
| `<leader>d…` | Diagnostics (line, buffer, project…) |
| `<leader>s…` | Workspaces (tabs with their own cwd); `<leader>s1..9` jumps by number |
| `<leader>u…` | Appearance (theme, statusline, indent guides…) |
| `:ReloadConfig` | Hot-reload the config (no restart) |
| `:Mason` / `:Lazy` | Manage LSP binaries / plugins |

> **Note:** some changes (the `blink.cmp` opts and the LSP spec) require a **restart**;
> everything else applies with `:ReloadConfig`.

---

## Platform notes

- **WSL / Windows:** there are platform-specific settings in `lua/config/options.lua`
  (PowerShell as the shell and `shellslash` on native Windows). For clipboard on WSL,
  install `win32yank`.
- **Fonts:** if you see boxes/garbled glyphs (`▯`) in the statusline or explorer, your
  terminal is missing a Nerd Font.
