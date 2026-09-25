-- clippy/sprite: dibujo de la mascota. Figura "stickman" en braille (2x4 puntos por celda);
-- cada pose es una rejilla de 8x16 puntos ('#' = encendido) que se empaqueta en 4x4 celdas.
-- Sin estado mutable: solo datos (poses), el empaquetador y los colores.
local api = vim.api
local M = {}

local COLS, ROWS = 4, 4
M.W, M.H = COLS, ROWS
M.ANIM_MS = 160 -- ms entre frames (marcha fluida)

M.POSES = {
  idle = {
    "   ##   ", "   ##   ", "   #    ", "  ###   ", " # # #  ", "   #    ", "   #    ", "   #    ",
    "  # #   ", "  # #   ", " #   #  ", " #   #  ", " #   #  ", "        ", "        ", "        ",
  },
  up_l = { -- caminar: pierna izquierda levantada (rodilla afuera), derecha apoyada al centro
    "   ##   ", "   ##   ", "   #    ", "  ###   ", " # # #  ", "   #    ", "   #    ", "   #    ",
    "   ##   ", "  # #   ", "  # #   ", "   ##   ", "    #   ", "        ", "        ", "        ",
  },
  up_r = { -- caminar: pierna derecha levantada (rodilla afuera), izquierda apoyada al centro
    "   ##   ", "   ##   ", "   #    ", "  ###   ", " # # #  ", "   #    ", "   #    ", "   #    ",
    "   ##   ", "   # #  ", "   # #  ", "   ##   ", "   #    ", "        ", "        ", "        ",
  },
  pass = { -- caminar: paso intermedio, piernas juntas al centro y figura 1 punto abajo (rebote)
    "        ", "   ##   ", "   ##   ", "   #    ", "  ###   ", " # # #  ", "   #    ", "   #    ",
    "   #    ", "   ##   ", "   ##   ", "   ##   ", "   ##   ", "        ", "        ", "        ",
  },
  wave = { -- saludo (al aparecer / feliz): brazo derecho en alto
    "   ## # ", "   ###  ", "   ##   ", "   #    ", "  ##    ", " # #    ", "   #    ", "   #    ",
    "  # #   ", "  # #   ", " #   #  ", " #   #  ", " #   #  ", "        ", "        ", "        ",
  },
  worried = { -- preocupado (errores): brazos arriba, alarmado
    " #    # ", " #    # ", " # ## # ", "  ####  ", "   #    ", "   #    ", "   #    ", "   #    ",
    "   ##   ", "   ##   ", "  #  #  ", "  #  #  ", " #    # ", "        ", "        ", "        ",
  },
  sleep = { -- dormido (inactividad): parado con "z z" arriba
    "   ## ##", "   ## # ", "   #    ", "  ###   ", " # # #  ", "   #    ", "   #    ", "   #    ",
    "  # #   ", "  # #   ", " #   #  ", " #   #  ", " #   #  ", "        ", "        ", "        ",
  },
}
M.WALK = { "up_l", "pass", "up_r", "pass" } -- ciclo de caminar

local BITS = { [0] = { 0x01, 0x02, 0x04, 0x40 }, [1] = { 0x08, 0x10, 0x20, 0x80 } }

-- Empaqueta una rejilla 8x16 en ROWS filas de COLS caracteres braille.
function M.pack(grid)
  local out = {}
  for cr = 0, ROWS - 1 do
    local line = {}
    for cc = 0, COLS - 1 do
      local val = 0
      for dx = 0, 1 do
        for dy = 0, 3 do
          local row = grid[cr * 4 + dy + 1] or ""
          if row:sub(cc * 2 + dx + 1, cc * 2 + dx + 1) == "#" then
            val = val + BITS[dx][dy + 1]
          end
        end
      end
      line[#line + 1] = vim.fn.nr2char(0x2800 + val)
    end
    out[cr + 1] = table.concat(line)
  end
  return out
end

M.MASCOT = M.pack(M.POSES.idle) -- figura base (tamaño y relleno inicial)

-- Colores: el stickman con color vivo (sin fondo); el bocadillo con el fg del tema.
function M.set_hl()
  local p = require("config.palette")
  api.nvim_set_hl(0, "ClippyMascot", { fg = p.green or p.blue, bg = "NONE", bold = true })
  api.nvim_set_hl(0, "ClippyNormal", { fg = p.fg, bg = "NONE" })
  api.nvim_set_hl(0, "ClippyBorder", { fg = p.fg, bg = "NONE" })
end

return M
