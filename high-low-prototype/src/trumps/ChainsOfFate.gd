extends TrumpCard

func execute_player(game_manager) -> void:
	is_used = true
	game_manager.enemy_cash_out_locked = true
	game_manager.status_label.text = "Player activated Chains of Fate! Enemy cannot cash out next turn."

func execute_enemy(game_manager, _enemy_ai) -> void:
	is_used = true
	game_manager.player_cash_out_locked = true
	game_manager.status_label.text = "Enemy activated Chains of Fate! Player cannot cash out next turn."

func can_enemy_use(game_manager, _enemy_ai) -> bool:
	if is_used:
		return false
	# Activate right before passing turn if shared pot >= 3 and active card is 7 or 8
	return game_manager.shared_pot >= 3 and (game_manager.active_card == 7 or game_manager.active_card == 8)
