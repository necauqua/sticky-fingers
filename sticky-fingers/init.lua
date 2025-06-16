--dofile('../api_def.lua')

dofile_once('mods/sticky-fingers/files/engine.lua')

local grease = {}
local enable_setting = ModSettingGet('sticky-fingers.enable')
local state_setting = ModSettingGet('sticky-fingers.show-state')
local state_gui = nil

local cheat_period = 1337 -- ~22 seconds

local cheat_buffer = '                    '
local cheat_frame = -cheat_period

function OnWorldPreUpdate()
    if not enable_setting or GameGetFrameNum() - cheat_frame < cheat_period then
        if not state_gui then
            state_gui = GuiCreate()
        end
        GuiStartFrame(state_gui)
        GuiColorSetForNextWidget(state_gui, 0.8, 0.2, 0.2, 1.0)
        GuiText(state_gui, 230, 6.5, 'A cheating bald cheater who cheats is playing right now!')
        return
    end

    local platform = get_platform()
    local controls = platform.app_config.keyboard_controls
    local keyboard = platform.keyboard
    local mouse = platform.mouse

    local saw = {}

    local function handle_press(keybind, control_check, control_set)
        if control_check == 0 then
            return
        end
        if control_set == 0 then
            control_set = control_check
        end

        if saw[control_check] then
            return
        end
        saw[control_check] = true

        if control_check > 0 then
            if InputIsKeyJustUp(control_check) then
                local state = grease[keybind]
                grease[keybind] = not state
                if control_set > 0 then
                    keyboard.keys_down[control_set] = not state
                else
                    local button_index = msb(-control_set) + 1
                    fire_mouse_button_event(button_index, not state)
                end
            end
        else
            local button_index = msb(-control_check) + 1
            if InputIsMouseButtonJustUp(button_index) then
                local state = grease[keybind]
                grease[keybind] = not state

                if control_set > 0 then
                    keyboard.keys_down[control_set] = not state
                else
                    local button_index2 = msb(-control_set) + 1
                    if not state then
                        mouse.buttons_just_up[button_index2] = 0
                        mouse.buttons_down[button_index2] = true
                        mouse.last_frame_buttons_pressed = mouse.last_frame_buttons_pressed - 60
                    end
                    fire_mouse_button_event(button_index2, not state)
                end
            end
        end
    end

    for _, keybind in pairs(KEYBINDS) do
        local control = controls[keybind]
        handle_press(keybind, control.primary, control.primary)
        handle_press(keybind, control.secondary, control.primary)
    end

    local input = tostring(platform.keyboard.text_input)
    cheat_buffer = string.sub(cheat_buffer .. input, #input + 1, 20)

    if cheat_buffer:match('i am bald$') then
        cheat_frame = GameGetFrameNum()
        cheat_buffer = '                    '
    end

    if not state_setting then
        return
    end

    local current_actions = get_current_actions()
    if #current_actions == 0 then
        return
    end
    if not state_gui then
        state_gui = GuiCreate()
    end
    GuiStartFrame(state_gui)
    GuiColorSetForNextWidget(state_gui, 0.8, 0.8, 0.8, 1.0)
    GuiText(state_gui, 230, 6.5, 'Pressed: ' .. table.concat(get_current_actions(), ', '))
end

function OnPausedChanged()
    enable_setting = ModSettingGet('sticky-fingers.enable')
    state_setting = ModSettingGet('sticky-fingers.show-state')
end
