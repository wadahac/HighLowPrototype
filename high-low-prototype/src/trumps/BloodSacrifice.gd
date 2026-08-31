extends TrumpCard

func execute_player(game_manager) -> void:
	is_used = true
	game_manager.player_hp = max(0, game_manager.player_hp - 2)
	game_manager.active_card = game_manager.draw_card()
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	game_manager._update_base_card_ui()
	game_manager.status_label.text = "Player activated Blood Sacrifice! Card replaced."
	game_manager.check_game_state()

func execute_enemy(game_manager, _enemy_ai) -> void:
	is_used = true
	game_manager.enemy_hp = max(0, game_manager.enemy_hp - 2)
	game_manager.active_card = game_manager.draw_card()
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	game_manager._update_base_card_ui()
	game_manager.status_label.text = "Enemy activated Blood Sacrifice! Card replaced."
	game_manager.check_game_state()

func can_enemy_use(game_manager, _enemy_ai) -> bool:
	if is_used:
		return false
	# Activate if Enemy HP > 5 AND active card is 7 or 8
	return game_manager.enemy_hp > 5 and (game_manager.active_card == 7 or game_manager.active_card == 8)
