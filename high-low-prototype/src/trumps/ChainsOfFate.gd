extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.enemy_cash_out_and_pass_locked:
		if game_manager.status_label:
			game_manager.status_label.text = "Enemy is already chained by Chains of Fate!"
		return

	is_used = true
	AudioManager.play_sfx("trump_chains")
	game_manager.enemy_cash_out_and_pass_locked = true
	game_manager.chained_target = "enemy"
	print("DEBUG - Chains Applied by Player: enemy_cash_out_and_pass_locked = ", game_manager.enemy_cash_out_and_pass_locked)
	if game_manager.status_label:
		game_manager.status_label.text = "Player activated Chains of Fate! Enemy cannot cash out or pass next turn."

func execute_enemy(game_manager, _enemy_ai) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.player_cash_out_and_pass_locked:
		if game_manager.status_label:
			game_manager.status_label.text = "Player is already chained by Chains of Fate!"
		return

	is_used = true
	AudioManager.play_sfx("trump_chains")
	game_manager.player_cash_out_and_pass_locked = true
	game_manager.chained_target = "player"
	print("DEBUG - Chains Applied by Enemy: player_cash_out_and_pass_locked = ", game_manager.player_cash_out_and_pass_locked)
	if game_manager.status_label:
		game_manager.status_label.text = "Enemy activated Chains of Fate! Player cannot cash out or pass next turn."

func can_enemy_use(game_manager, enemy_ai) -> bool:
	if not can_activate(game_manager):
		return false
	if not enemy_ai or not (self in enemy_ai.trumps_hand):
		return false
	if game_manager.enemy_cash_out_and_pass_locked or game_manager.player_cash_out_and_pass_locked:
		return false
	# Activate when shared pot >= 3 and active card is 7 or 8
	return game_manager.shared_pot >= 3 and (game_manager.active_card == 7 or game_manager.active_card == 8)
