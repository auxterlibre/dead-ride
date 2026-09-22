extends Node

var camera_follow: CameraFollow
var road_network: RoadNetwork  # the painted roads, as a graph NPC drivers route over
var wind: Wind  # one direction and gust for everything that blows
var heat: HeatWave  # the 10-16h scorch window and its screen haze
var build_grid: BuildGrid  # where placed structures snap and what stands there
var sleep_transition: SleepTransition  # game.tscn's night lapse; null headless
var debug_mode: bool = false  # key 9 (debug_text_toggle); debug visuals watch this
var debug_labels: bool = false
var debug_stats: bool = true
