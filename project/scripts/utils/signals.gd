extends Node

signal spread_updated(total)
signal aim_distance_updated(distance, too_far)
signal ammo_updated  # the equipped weapon's magazine changed; listeners re-read it
signal health_updated(current, max)
signal player_died  # THE player only; Character.died stays per-body for brains
signal energy_updated(current, max)  # the player's survival battery
signal heat_burning_changed(burning)  # the sun is/stopped cooking the player
signal weapon_setup(weapon)  # the drawn WeaponData; null = hands empty
signal weapon_fired
signal notification_requested(text, type)  # display-ready text + Enums.MessageType; emitters own both
signal aim_state_changed(is_aiming)

signal drive_state_changed(is_driving)
signal vehicle_speed_updated(speed)  # m/s, while driven
signal vehicle_fuel_updated(current, max)  # liters, while driven
signal vehicle_health_updated(current, max)

signal backpack_state_changed(is_open, with_container)
signal carry_state_changed(carrying)  # a barrel in the arms; the bar hides on it
signal container_opened(title, inventory)  # a world container (car trunk) opened
signal planting_opened(plot, spot)  # a bare crop spot asking what to grow
signal inventory_changed(inventory)  # a container's contents moved
signal quick_slots_updated(entries, active_index)

# placement is an Enums.PromptPlacement; input_action is the InputMap action a
# clickable prompt fires, empty for hints that are only ever read.
signal input_info_added(keys, label, placement, input_action)
signal interaction_hint_added(source)  # an InteractiveArea worth a dot
signal interaction_hint_removed(source)
signal interaction_menu_requested(title, options)  # [{label, target, callback}]
signal input_info_removed(keys)
signal input_device_changed(pad_active)
signal noise_emitted(position, range, source)  # world sounds AI can hear
signal structure_changed(position)  # something was built or pulled down here

signal calendar_updated(time_data)  # game clock tick, once per in-game minute

signal money_changed(total)  # the player's purse, after any transaction
signal pump_stock_changed(current, max)  # liters held by the station's pump

signal settings_changed  # a player setting was altered; UI re-renders itself

signal alert_raised(source, quarry)  # a character calling out a contact to allies
