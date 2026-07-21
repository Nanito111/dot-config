-- Librería de primitivas UI reutilizables (plugin-free). Agrega los submódulos:
--   ui.geom.center · ui.close · ui.win.set_opts · ui.hl.span/line_marks · ui.text.fit/pad
--   ui.backdrop.open   (y, en fases siguientes, ui.float · ui.menu · ui.input)
return {
  geom = require("plugins.local.ui.geom"),
  close = require("plugins.local.ui.close"),
  win = require("plugins.local.ui.win"),
  hl = require("plugins.local.ui.hl"),
  text = require("plugins.local.ui.text"),
  backdrop = require("plugins.local.ui.backdrop"),
}
