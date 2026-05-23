-- colors.lua
-- Migrated from colors.conf
-- NOTE: Este archivo no fue incluido en el zip, por lo que debes migrarlo tú mismo.
-- La sintaxis cambia de:
--   $primary = rgba(...)
-- a:
--   primary = "rgba(...)"
-- Y luego referenciarlo en look-and-feel.lua directamente como variables Lua.
--
-- Ejemplo:
primary           = "rgba(cba6f7ff)"
surface_bright    = "rgba(313244ff)"
background        = "rgba(1e1e2eff)"
shadow            = "rgba(00000066)"
tertiary          = "rgba(f38ba8ff)"
tertiary_container = "rgba(45475aff)"

return {
    primary            = primary,
    surface_bright     = surface_bright,
    background         = background,
    shadow             = shadow,
    tertiary           = tertiary,
    tertiary_container = tertiary_container,
}
