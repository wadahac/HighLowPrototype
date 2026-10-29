extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.shared_pot < 2:
		game_manager.set_status("Executioner needs at least 2 in the pot!", "warn")
		return
	if game_manager.executioner_sentence_turns > 0:
		game_manager.set_status("An Executioner's Sentence is already active!", "warn")
		return

	is_used = true
	AudioManager.play_sfx("trump_executioner")
	game_manager.start_executioner_sentence("player")

func execute_enemy(game_manager, _enemy_ai) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.shared_pot < 2:
		return
	if game_manager.executioner_sentence_turns > 0:
		return

	is_used = true
	AudioManager.play_sfx("trump_executioner")
	game_manager.start_executioner_sentence("enemy")

func can_enemy_use(game_manager, enemy_ai) -> bool:
	if not can_activate(game_manager):
		return false
	if not enemy_ai or not (self in enemy_ai.trumps_hand):
		return false
	if game_manager.executioner_sentence_turns > 0:
		return false
	if game_manager.shared_pot < 2:
		return false
	# Seal a meaningful pot, or set up a lethal sentence against a low-HP player.
	return game_manager.shared_pot >= 4 or game_manager.shared_pot >= game_manager.player_hp
