extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	is_used = true
	game_manager.mirror_active = true
	game_manager.status_label.text = "Player activated Mirror Shard! Backfire damage will be reflected."

func execute_enemy(game_manager, _enemy_ai) -> void:
	is_used = true
	game_manager.mirror_active = true
	game_manager.status_label.text = "Enemy activated Mirror Shard!"

func can_enemy_use(game_manager, _enemy_ai) -> bool:
	if is_used:
		return false
	# Activate before taking a High/Low guess with ~50% success probability (card is 6, 7, 8)
	return game_manager.active_card >= 6 and game_manager.active_card <= 8
