---@diagnostic disable: undefined-global

dofile_once("data/scripts/lib/mod_settings.lua")

MOD_ID = "sticky-fingers"

mod_settings = {
    {
        id = "enable",
        ui_name = "Enable",
        ui_description = "So you can disable the mod without restarting the game.",
        value_default = true,
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
        id = "show-state",
        ui_name = "Show state",
        ui_description = "Show currently pressed keybinds on screen at all time.",
        value_default = true,
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
}

function ModSettingsUpdate(init_scope)
    mod_settings_update(MOD_ID, mod_settings, init_scope)
end

function ModSettingsGuiCount()
    return mod_settings_gui_count(MOD_ID, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
    mod_settings_gui(MOD_ID, mod_settings, gui, in_main_menu)
end
