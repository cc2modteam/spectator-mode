g_animation_time = 0
g_is_beep = false
g_beep_next = 0

function begin()
    begin_load()
end

function update(screen_w, screen_h, ticks) 
    g_animation_time = g_animation_time + ticks

    local vehicle = update_get_screen_vehicle()
    local attachment_indices = { 8, 7 }

    if update_screen_overrides(screen_w, screen_h, ticks)  then return end

    if vehicle:get() then
        local team = update_get_team(vehicle:get_team())

        if team:get() then
            local attachments = {}

            for i = 1, #attachment_indices do
                local attachment = vehicle:get_attachment(attachment_indices[i])

                if attachment:get() then
                    table.insert(attachments, attachment)
                end
            end

            local border_out = 6
            local border_in = 2
            local section_w = (screen_w - 2 * border_out - border_in) / 2
            local section_h = screen_h - 2 * border_out

            render_attachment_info(border_out, border_out, section_w, section_h, attachments[1], vehicle, team, update_get_loc(e_loc.upp_icbm))
            render_attachment_info(border_out + section_w + border_in, border_out, section_w, section_h, attachments[2], vehicle, team, update_get_loc(e_loc.upp_gun))
        end
    end

    if g_is_beep then
        if g_animation_time >= g_beep_next then
            g_beep_next = g_animation_time + 10
            g_is_beep = false
            update_play_sound(e_audio_effect_type.telemetry_5)
        end
    else
        g_beep_next = g_animation_time
    end
end

function input_event(event, action)
    if action == e_input_action.press then
        if event == e_input.back then
            update_set_screen_state_exit()
        end
    end
end

function input_axis(x, y, z, w)
end


--------------------------------------------------------------------------------
--
-- ATTACHMENT INFO
--
--------------------------------------------------------------------------------

function render_attachment_info(x, y, w, h, attachment, vehicle, team, name)
    update_ui_push_offset(x, y)

    local col = color_white

    if attachment == nil then
        render_status_label(2, h / 2 - 7, w - 4, 13, update_get_loc(e_loc.upp_offline), col, is_blink_on(15))
    else
        local definition_index = attachment:get_definition_index()
        local ammo_capacity = attachment:get_ammo_capacity()
        local ammo_remaining = attachment:get_ammo_remaining()
        local target_accuracy = attachment:get_target_accuracy() / 255 * 100
        local control_mode = attachment:get_control_mode()

        local target_id = team:get_consuming_attachment_target(vehicle:get_id(), attachment:get_index())
        local target_vehicle_id = 0
        local target_attachment_index = 0
        local target_state = 0
        
        if target_id ~= 0 then
            target_vehicle_id, target_attachment_index = team:get_weapon_target_parent_id(target_id)
            target_state = team:get_weapon_target_state(target_id)
        end

        if target_state ~= 1 then
            target_vehicle_id = 0
            target_attachment_index = 0
            target_id = 0
        end

        if target_id == 0 then
            target_accuracy = 0
        end

        local _, icon = get_attachment_icons(definition_index)

        local cy = 2
        local cx = 2
        
        if attachment:get_is_damaged() then
            if control_mode == "off" then
                render_status_label(2, h / 2 - 7, w - 4, 13, update_get_loc(e_loc.upp_damaged), color_status_bad, is_blink_on(15))
            else
                update_ui_image(cx, cy, icon, col, 0)
                update_ui_line(cx + 18, 0, cx + 18, 19, col)
                update_ui_text(cx + 21, cy + 4, name, 200, 0, col, 0)
                cy = cy + 17
                update_ui_line(0, cy, w, cy, col)
        
                render_status_label(2, h / 2 - 7, w - 4, 13, update_get_loc(e_loc.upp_damaged), color_status_bad, is_blink_on(15))
            end
        elseif control_mode == "off" then
            render_status_label(2, h / 2 - 7, w - 4, 13, update_get_loc(e_loc.upp_offline), col, is_blink_on(15))
        else
            update_ui_image(cx, cy, icon, col, 0)
            update_ui_line(cx + 18, 0, cx + 18, 19, col)
            update_ui_text(cx + 21, cy + 4, name, 200, 0, col, 0)
            cy = cy + 17
    
            update_ui_line(0, cy, w, cy, col)
            cy = cy + 2

            render_ammo_bar(w - 5, cy, 20, clamp(ammo_remaining / ammo_capacity, 0, 1), col)

            cx = 4
            update_ui_image(cx, cy, atlas_icons.column_ammo, iff(ammo_remaining > 0, col, color_status_bad), 0)
            update_ui_text(cx + 10, cy, math.min(ammo_remaining, 99999), 200, 0, iff(ammo_remaining > 0, col, color_status_bad), 0)
            cy = cy + 10

            update_ui_image(cx, cy, atlas_icons.column_laser, iff(target_id ~= 0, col, color_grey_dark), 0)
            update_ui_text(cx + 10, cy, string.format("%.0f%%", target_accuracy), 200, 0, iff(target_id ~= 0, col, color_grey_dark), 0)
            cy = cy + 11

            if target_id ~= 0 then
                if ammo_remaining > 0 then
                    render_status_label(2, h - 15, w - 4, 13, update_get_loc(e_loc.upp_tracking), color_status_bad, is_blink_on(5))
                    g_is_beep = true
                else
                    render_status_label(2, h - 15, w - 4, 13, update_get_loc(e_loc.upp_empty), color_status_bad, true)
                end
            else
                if ammo_remaining > 0 then
                    render_status_label(2, h - 15, w - 4, 13, update_get_loc(e_loc.upp_armed), color_status_ok, true)
                else
                    render_status_label(2, h - 15, w - 4, 13, update_get_loc(e_loc.upp_empty), color_status_bad, true)
                end
            end

            local function render_missile(x, y, is_ammo, is_tracking)
                update_ui_push_offset(x, y)

                if is_ammo and is_tracking then
                    update_ui_image(1, 1, atlas_icons.screen_weapon_missile_cruise, iff(is_blink_on(5), color_black, color_status_bad), 0)
                else
                    update_ui_image(1, 1, atlas_icons.screen_weapon_missile_cruise, iff(is_ammo, color_status_ok, color_grey_dark), 0)
                end

                update_ui_pop_offset()
            end

            local function render_shell(x, y, is_ammo, is_tracking)
                update_ui_push_offset(x, y)

                if is_ammo and is_tracking then
                    update_ui_image(1, 1, atlas_icons.screen_weapon_shell, iff(is_blink_on(5), color_black, color_status_bad), 0)
                else
                    update_ui_image(1, 1, atlas_icons.screen_weapon_shell, iff(is_ammo, color_status_ok, color_grey_dark), 0)
                end

                update_ui_pop_offset()
            end

            update_ui_line(0, cy, w, cy, col)
            cy = cy + 1

            if target_vehicle_id ~= 0 then
                local target_vehicle = update_get_map_vehicle_by_id(target_vehicle_id)
                local definition_index = -1
                
                if target_vehicle:get() then
                    definition_index = target_vehicle:get_definition_index()
                end

                local _, icon, handle = get_chassis_data_by_definition_index(definition_index)

                update_ui_rectangle(0, cy, w, 11, col)
                update_ui_text(0, cy + 1, update_get_loc(e_loc.upp_order), math.floor(w / 2) * 2, 1, color_black, 0)
                cy = cy + 15

                update_ui_image(cx, cy, icon, color_white, 0)
                update_ui_text(cx + 19, cy + 3, handle, 200, 0, color_white, 0)
                update_ui_image(cx + 41, cy + 3, atlas_icons.column_controlling_peer, iff(is_blink_on(5), color_grey_dark, color_status_ok), 0)
            else                
                update_ui_rectangle(0, cy, w, 11, color_grey_dark)
                update_ui_text(0, cy + 1, update_get_loc(e_loc.upp_order), math.floor(w / 2) * 2, 1, color_black, 0)
                cy = cy + 15

                update_ui_text(0, cy + 3, "---", math.floor(w / 2) * 2, 1, color_grey_dark, 0)
            end

            local y = h - 37

            if definition_index == e_game_object_type.attachment_turret_carrier_missile_silo then
                update_ui_line(0, y - 1, w, y - 1, col)

                for i = 0, 5 do
                    render_missile(1 + i * 9, y, ammo_remaining > i, ammo_remaining == i + 1 and target_id ~= 0)
                end
            else
                update_ui_line(0, y - 1, w, y - 1, col)

                for i = 0, 9 do
                    render_shell(3 + i * 5, y, ammo_remaining > i, ammo_remaining == i + 1 and target_id ~= 0)
                    render_shell(3 + i * 5, y + 10, ammo_remaining > i + 10, ammo_remaining == i + 11 and target_id ~= 0)
                end
            end
        end
    end

    update_ui_rectangle_outline(0, 0, w, h, col)

    update_ui_pop_offset()
end


--------------------------------------------------------------------------------
--
-- UTIL
--
--------------------------------------------------------------------------------

function render_status_label(x, y, w, h, text, col, is_outline, back_col)
    x = math.floor(x)
    y = math.floor(y)

    update_ui_push_offset(x, y)
    
    if is_outline then
        update_ui_rectangle_outline(0, 0, w, h, col)
        update_ui_text(0, h / 2 - 4, text, math.ceil(w / 2) * 2, 1, col, 0)    
    else
        update_ui_rectangle(0, 0, w, h, col)
        update_ui_text(0, h / 2 - 4, text, math.ceil(w / 2) * 2, 1, back_col or color_black, 0)    
    end

    update_ui_pop_offset()
end

function is_blink_on(rate, is_pulse)
    if is_pulse == nil or is_pulse == false then
        return g_animation_time % (2 * rate) > rate
    else
        return g_animation_time % (2 * rate) == 0
    end
end

function render_ammo_bar(x, y, h, factor, col)
    update_ui_push_offset(x, y)

    local bar_size = math.floor(factor * (h - 4));
    update_ui_rectangle(0, math.floor(h - bar_size - 2), 2, bar_size, col)
    update_ui_rectangle(-1, h - 1, 4, 1, col)
    update_ui_rectangle(-1, 0, 4, 1, col)

    local segments = 4
    local step = h / segments
    
    for i = 1, segments - 1 do
        if i % 4 == 0 then
            update_ui_rectangle(-1, h - i * step, 3, 1, col)
        elseif i % 2 == 0 then
            update_ui_rectangle(-1, h - i * step, 2, 1, col)
        else
            update_ui_rectangle(-1, h - i * step, 1, 1, col)
        end
    end

    update_ui_pop_offset()
end
