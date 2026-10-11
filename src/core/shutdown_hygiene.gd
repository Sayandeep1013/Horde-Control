class_name ShutdownHygiene
extends RefCounted
## One shutdown hook for every static cache that holds a Resource or Object
## (decision D256). The engine reports "resources still in use at exit" and
## "ObjectDB instances leaked at exit" for anything a `static var` still
## references when the tree is torn down; BootCheck (first autoload, so the
## last autoload to leave the tree) calls `release_all()` from `_exit_tree`.
## Also stops every AudioStreamPlayer still playing, because a live playback
## keeps its stream (and the decoder objects) referenced past the leak report.
## Add any new static Resource/Object cache here, not at its call site.


const AUDIO_DRAIN_MSEC: int = 300


static func release_all(tree: SceneTree = null) -> void:
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		_stop_players(tree.root)
		# Stopped playbacks are only deleted by the audio thread's next mix
		# passes (fade-out, then deletion); quitting before that leaves the
		# AudioStreamPlayback objects (and their streams) in the engine's leak
		# report. Give the mixer time to retire them.
		OS.delay_msec(AUDIO_DRAIN_MSEC)
	Sfx.release_caches()
	RunConfig.release_caches()
	WarChestArt.release_caches()
	AbilityDisplay.release_caches()
	FieldGuideCatalog.release_caches() # PT-UI: script constant maps
	UiShapeGlyph.release_caches()
	HudGlyphs.release_caches()
	UiTheme.release_caches()
	BloodFx.release_caches()
	DamageNumberFx.release_caches()
	StatusEffects.release_caches()
	AbilityDamage.reset()


static func _stop_players(node: Node) -> void:
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).stop()
		(node as AudioStreamPlayer).stream = null
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).stop()
		(node as AudioStreamPlayer2D).stream = null
	for c in node.get_children():
		_stop_players(c)
