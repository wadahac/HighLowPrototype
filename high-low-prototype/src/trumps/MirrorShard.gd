extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.mirror_active:
		game_manager.set_status("Mirror Shard is already active!", "warn")
		return

	is_used = true
	AudioManager.play_sfx("trump_mirror")
	game_manager.mirror_active = true
	game_manager.mirror_owner = "player"
	game_manager.set_status("Player activated Mirror Shard! Backfire damage will be reflected.", "good")
	game_manager.refresh_effect_badges()

func execute_enemy(game_manager, _enemy_ai) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.mirror_active:
		return
	if game_manager.shared_pot < 2:
		return

	is_used = true
	AudioManager.play_sfx("trump_mirror")
	game_manager.mirror_active = true
	game_manager.mirror_owner = "enemy"
	game_manager.set_status("Enemy activated Mirror Shard!", "bad")
	game_manager.refresh_effect_badges()

func can_enemy_use(game_manager, enemy_ai) -> bool:
	if not can_activate(game_manager):
		return false
	if not enemy_ai or not (self in enemy_ai.trumps_hand):
		return false
	if game_manager.mirror_active:
		return false
	if game_manager.shared_pot < 2:
		return false
	# Activate before taking a High/Low guess with ~50% success probability (card is 6, 7, 8)
	return game_manager.active_card >= 6 and game_manager.active_card <= 8
