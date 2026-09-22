class_name DebugLabel
extends RichTextLabel


func _ready():
	text = ""

func _process(_delta):
	if visible != Globals.debug_stats:
		visible = Globals.debug_stats
		if not visible:
			text = ""
	if not visible:
		return
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var process := Performance.get_monitor(Performance.TIME_PROCESS)
	var physics := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)

	var fps_color := "lime_green"
	if int(fps) < 25.0: fps_color = "indian_red"
	elif int(fps) < 50.0: fps_color = "gold"

	# physics step is the real gameplay CPU cost here
	text = "[bgcolor=black] [color=%s]%d FPS[/color] [/bgcolor]  " % [fps_color, fps]
	text += "[bgcolor=black] [color=slate_gray]Process:[/color] %0.2fms [/bgcolor]  " % (process * 1000.0)
	text += "[bgcolor=black] [color=slate_gray]Physics:[/color] %0.2fms [/bgcolor]" % (physics * 1000.0)

	var orphans = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	if orphans > 0:
		text += "  [bgcolor=web_maroon] Orphan nodes: %d [/bgcolor]" % orphans
