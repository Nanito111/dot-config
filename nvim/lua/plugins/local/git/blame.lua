-- Git blame de la línea actual en un popup flotante.
local api = vim.api
local signs = require("plugins.local.git.signs")
local ui = require("plugins.local.ui")
local M = {}

local ns = api.nvim_create_namespace("git_blame")

local function reltime(ts)
  if not ts then
    return "?"
  end
  local diff = os.time() - tonumber(ts)
  local mins = math.floor(diff / 60)
  if mins < 1 then
    return "now"
  elseif mins < 60 then
    return mins .. "m ago"
  end
  local hrs = math.floor(mins / 60)
  if hrs < 24 then
    return hrs .. "h ago"
  end
  local days = math.floor(hrs / 24)
  if days < 30 then
    return days .. "d ago"
  end
  local months = math.floor(days / 30)
  if months < 12 then
    return months .. " mo ago"
  end
  return math.floor(months / 12) .. " y ago"
end

-- Abre un popup flotante junto al cursor con el blame de la línea actual
local function open_popup(lines, line_hls)
  local width = 1
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end

  local pbuf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(pbuf, 0, -1, false, lines)
  for i, hl in ipairs(line_hls) do
    if hl then
      pcall(api.nvim_buf_set_extmark, pbuf, ns, i - 1, 0, {
        end_row = i,
        end_col = 0,
        hl_group = hl,
      })
    end
  end
  vim.bo[pbuf].modifiable = false

  ui.float.open({
    buf = pbuf,
    enter = true,
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = #lines,
    title = "  git blame ",
    title_pos = "left",
    close_keys = { "<Esc>", "q", "<C-c>" },
    close_on_leave = true,
  })
end

-- Muestra el blame de la línea actual en un popup
function M.blame()
  local buf = api.nvim_get_current_buf()
  if vim.fn.executable("git") == 0 or not signs.is_file(buf) then
    vim.notify("git blame: not available here", vim.log.levels.WARN)
    return
  end
  local name = api.nvim_buf_get_name(buf)
  local dir = vim.fn.fnamemodify(name, ":h")
  local file = vim.fn.fnamemodify(name, ":t")
  local line = api.nvim_win_get_cursor(0)[1]

  vim.system(
    { "git", "blame", "-L", line .. "," .. line, "--porcelain", "--", file },
    { cwd = dir, text = true },
    function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          vim.notify("git blame failed (untracked file?)", vim.log.levels.WARN)
          return
        end
        local out = res.stdout or ""
        local hash = out:match("^(%x+)")
        if hash and hash:match("^0+$") then
          open_popup({ " Uncommitted (local changes)" }, { "GitBlame" })
          return
        end
        local author = out:match("author ([^\n]+)") or "?"
        local ts = tonumber(out:match("author%-time (%d+)"))
        local summary = out:match("summary ([^\n]+)") or ""
        local fecha = ts and (reltime(ts) .. " (" .. os.date("%Y-%m-%d", ts) .. ")") or "?"
        open_popup({
          " " .. author,
          " " .. (hash and hash:sub(1, 8) or "") .. " · " .. fecha,
          " " .. summary,
        }, { "GitBlameAuthor", "GitBlame", "Normal" })
      end)
    end
  )
end

return M
