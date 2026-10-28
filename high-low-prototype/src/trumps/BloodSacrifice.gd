extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.player_hp <= 2:
		game_manager.set_status("Not enough HP to sacrifice!", "warn")
		return

	is_used = true
	AudioManager.play_sfx("trump_sacrifice")
	game_manager.player_hp = max(0, game_manager.player_hp - 2)
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	var new_card: int = game_manager.replace_active_card()

	var card_str: String = game_manager.get_card_name(new_card)
	game_manager.set_status("Blood Sacrifice activated! Sacrificed 2 HP and drew a new card: " + card_str, "warn")

	game_manager.check_game_state()

func execute_enemy(game_manager, _enemy_ai) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.enemy_hp <= 2:
		return

	is_used = true
	AudioManager.play_sfx("trump_sacrifice")
	game_manager.enemy_hp = max(0, game_manager.enemy_hp - 2)
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	var new_card: int = game_manager.replace_active_card()

	var card_str: String = game_manager.get_card_name(new_card)
	game_manager.set_status("Enemy activated Blood Sacrifice! Sacrificed 2 HP and drew a new card: " + card_str, "bad")

	game_manager.check_game_state()

func can_enemy_use(game_manager, enemy_ai) -> bool:
	if not can_activate(game_manager):
		return false
	if not enemy_ai or not (self in enemy_ai.trumps_hand):
		return false
	# Activate if Enemy HP > 2 AND active card is 7 or 8
	return game_manager.enemy_hp > 2 and (game_manager.active_card == 7 or game_manager.active_card == 8)
