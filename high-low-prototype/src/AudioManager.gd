extends Node

# Preloaded Sound Effects
var sfx_dict: Dictionary = {
	"card_flip": preload("res://assets/SFX/card-flip.mp3"),
	"card_place": [
		preload("res://assets/SFX/cardPlace1.ogg"),
		preload("res://assets/SFX/cardPlace2.ogg"),
		preload("res://assets/SFX/cardPlace3.ogg")
	],
	"click": [
		preload("res://assets/SFX/click-a.ogg"),
		preload("res://assets/SFX/click-b.ogg")
	],
	"switch_turn": [
		preload("res://assets/SFX/switch-a.ogg"),
		preload("res://assets/SFX/switch-b.ogg")
	],
	"cash_out": [
		preload("res://assets/SFX/chipsCollide1.ogg"),
		preload("res://assets/SFX/chipsCollide2.ogg"),
		preload("res://assets/SFX/chipsCollide3.ogg")
	],
	"game_over": preload("res://assets/SFX/level_fail.mp3"),
	"take_damage": preload("res://assets/SFX/heavy_thud.mp3"),
	"trump_chains": preload("res://assets/SFX/chains.mp3"),
	"trump_sacrifice": preload("res://assets/SFX/blood_splash.mp3"),
	"trump_executioner": preload("res://assets/SFX/sword_slash.mp3"),
	"trump_vision": preload("res://assets/SFX/ghostly-whispering.mp3"),
	"trump_thievery": preload("res://assets/SFX/tp.mp3"),
	"trump_mirror": preload("res://assets/SFX/broken_glass.mp3")
}

func play_sfx(sfx_name: String, pitch_variance: float = 0.05) -> void:
	if not sfx_dict.has(sfx_name):
		push_warning("SFX key not found: " + sfx_name)
		return
		
	var stream: AudioStream = null
	var entry = sfx_dict[sfx_name]
	
	if entry is Array:
		stream = entry.pick_random()
	elif entry is AudioStream:
		stream = entry
		
	if stream == null:
		return

	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
