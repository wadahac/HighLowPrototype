extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	is_used = true
	game_manager.enemy_cash_out_and_pass_locked = true
	game_manager.chained_target = "enemy"
	game_manager.chains_lock_duration = 1
	print("DEBUG - Chains Applied by Player: enemy_cash_out_and_pass_locked = ", game_manager.enemy_cash_out_and_pass_locked)
	game_manager.status_label.text = "Player activated Chains of Fate! Enemy cannot cash out or pass next turn."

func execute_enemy(game_manager, _enemy_ai) -> void:
	is_used = true
	game_manager.player_cash_out_and_pass_locked = true
	game_manager.chained_target = "player"
	game_manager.chains_lock_duration = 1
	print("DEBUG - Chains Applied by Enemy: player_cash_out_and_pass_locked = ", game_manager.player_cash_out_and_pass_locked)
	game_manager.status_label.text = "Enemy activated Chains of Fate! Player cannot cash out or pass next turn."

func can_enemy_use(game_manager, _enemy_ai) -> bool:
	if is_used:
		return false
	# Activate when shared pot >= 3 and active card is 7 or 8
	return game_manager.shared_pot >= 3 and (game_manager.active_card == 7 or game_manager.active_card == 8)
