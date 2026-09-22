extends ProbeBase
# WINDOWED look check for the revamped pause menu (headless renders blank):
# opens the panel and saves it for a side-by-side against the Figma frame.
# The metrics it asserts are the mockup's literal pixels - the design frame and
# the viewport are both 3840x2160, so a number here IS the number there.

const PANEL: Vector2 = Vector2(1174, 816)  # Figma 168:1325
const SETTINGS_PANEL: Vector2 = Vector2(2378, 1646)  # Figma 168:1114
const BUTTON_HEIGHT: float = 112.0  # Figma 168:1339
const BUTTON_PITCH: float = 144.0  # 112 tall on a 144 grid = 32 apart


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # open() pauses the tree
	if not windowed("the pause menu"):
		finish()
		return
	var menu: PauseMenu = load("res://scenes/ui/menus/pause_menu.tscn").instantiate()
	add_child(menu)
	menu.open()
	await settle(20)
	var panel: Control = menu.get_node("Panel")
	check(panel.size.is_equal_approx(PANEL), "the panel is the mockup's size",
			"%s vs %s" % [panel.size, PANEL])
	check(is_equal_approx(panel.global_position.x + panel.size.x * 0.5, 1920.0)
			and is_equal_approx(panel.global_position.y + panel.size.y * 0.5, 1080.0),
			"centred on the screen", str(panel.global_position))
	var resume: Button = menu.resume_button
	var settings: Button = menu.settings_button
	check(is_equal_approx(resume.size.y, BUTTON_HEIGHT),
			"buttons are 112 tall", "%.0f" % resume.size.y)
	check(is_equal_approx(settings.global_position.y - resume.global_position.y,
			BUTTON_PITCH), "stacked on the mockup's 144 pitch",
			"%.0f apart" % (settings.global_position.y - resume.global_position.y))
	check(resume.primary and not settings.primary,
			"Resume is the primary fill and the rest are not",
			"%s / %s" % [resume.primary, settings.primary])
	check(menu.menu_button.disabled,
			"the main-menu button is plainly not ready rather than lying",
			"disabled")
	save_shot(await capture(), "pause_menu")

	# --- the settings panel, on the tab with the most shapes in it
	var panel_scene: PackedScene = load("res://scenes/ui/menus/settings_screen.tscn")
	var screen: SettingsScreen = panel_scene.instantiate()
	add_child(screen)
	menu.hide()
	screen.open()
	screen.show_tab(SettingsScreen.Tab.CONTROLS)
	await settle(20)
	var body: Control = screen.get_node("Panel")
	check(body.size.is_equal_approx(SETTINGS_PANEL),
			"the settings panel is the mockup's size",
			"%s vs %s" % [body.size, SETTINGS_PANEL])
	check(screen.tab_bar.get_child_count() == 4,
			"four tabs across the top",
			"%d tabs" % screen.tab_bar.get_child_count())
	check(screen.tabs[SettingsScreen.Tab.CONTROLS].selected
			and not screen.tabs[SettingsScreen.Tab.AUDIO].selected,
			"exactly the open one is lit", "controls")
	# A tab FILTERS: every row exists all the time, so a pick cannot be lost by
	# switching away and back.
	var shown: int = 0
	for row in screen.rows:
		if screen.rows[row].visible:
			shown += 1
	check(shown == 4, "the controls tab shows its four rows and no others",
			"%d visible of %d" % [shown, screen.rows.size()])
	check(screen.rows[SettingsScreen.Row.GAMEPAD_HEADER].kind
			== SettingsRow.Kind.HEADER
			and screen.rows[SettingsScreen.Row.LOOK_SENSITIVITY].kind
			== SettingsRow.Kind.SLIDER,
			"with a header over sliders, the design's own row kinds", "header+slider")
	check(screen.bindings_button.disabled and screen.reset_button.disabled,
			"and the two features that do not exist yet are plainly disabled",
			"bindings/reset off")
	# At REST a slider row is a label and a percentage - the design's Default
	# state has no track at all, which is the thing an eyeball would have got
	# wrong and built as an always-on bar.
	check(not screen.rows[SettingsScreen.Row.LOOK_SENSITIVITY].slider.visible,
			"a slider row shows no track until it is pointed at", "bare")
	save_shot(await capture(), "settings_controls")

	# ...and under the pointer the pill appears BEHIND the percentage.
	var slider_row: SettingsRow = screen.rows[SettingsScreen.Row.LOOK_SENSITIVITY]
	await point_at(slider_row)
	check(slider_row.hovered and slider_row.slider.visible
			and slider_row.wash.visible and slider_row.slider_value.visible,
			"hovering grows the track and keeps the value on top of it",
			"track+wash+value")

	# The bug this guards: moving ONTO the row own control used to fire
	# mouse_exited, hiding what the pointer had just reached.
	await point_at(slider_row.slider)
	check(slider_row.hovered and slider_row.slider.visible,
			"and the track survives the pointer landing on it",
			"mouse %s" % get_viewport().get_mouse_position())
	var list_row: SettingsRow = screen.rows[SettingsScreen.Row.INVERT_LOOK_Y]
	await point_at(list_row)
	await point_at(list_row.next_button)
	var gap_left: float = list_row.value_label.global_position.x \
			- list_row.prev_button.get_global_rect().end.x
	var gap_right: float = list_row.next_button.global_position.x \
			- list_row.value_label.get_global_rect().end.x
	check(absf(gap_left - gap_right) < 1.0,
			"the value sits centred between the two arrows",
			"%.1f left vs %.1f right" % [gap_left, gap_right])
	check(list_row.hovered and list_row.next_button.visible,
			"so does an arrow the pointer reaches for",
			"mouse %s in arrow %s" % [get_viewport().get_mouse_position(),
			list_row.next_button.get_global_rect()])
	save_shot(await capture(), "settings_row_hover")
	finish()


# warp_mouse takes WINDOW pixels; get_mouse_position returns VIEWPORT pixels,
# and canvas_items stretch makes those differ by the window/viewport ratio.
func point_at(p_control: Control):
	var view: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	Input.warp_mouse(p_control.get_global_rect().get_center() * win / view)
	await settle(10)
