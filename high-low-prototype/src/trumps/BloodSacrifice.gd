extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	if game_manager.player_hp <= 2:
		if game_manager.status_label:
			game_manager.status_label.text = "Not enough HP to sacrifice!"
		return

	is_used = true
	game_manager.player_hp = max(0, game_manager.player_hp - 2)
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	var new_card = game_manager.replace_active_card()
	
	var names = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	var card_str = names[new_card] if new_card >= 1 and new_card <= 13 else str(new_card)
	if game_manager.status_label:
		game_manager.status_label.text = "Blood Sacrifice activated! Sacrificed 2 HP and drew a new card: " + card_str
	
	game_manager.check_game_state()

func execute_enemy(game_manager, _enemy_ai) -> void:
	if game_manager.enemy_hp <= 2:
		return

	is_used = true
	game_manager.enemy_hp = max(0, game_manager.enemy_hp - 2)
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	var new_card = game_manager.replace_active_card()
	
	var names = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	var card_str = names[new_card] if new_card >= 1 and new_card <= 13 else str(new_card)
	if game_manager.status_label:
		game_manager.status_label.text = "Enemy activated Blood Sacrifice! Sacrificed 2 HP and drew a new card: " + card_str
	
	game_manager.check_game_state()

func can_enemy_use(game_manager, _enemy_ai) -> bool:
	if is_used:
		return false
	# Activate if Enemy HP > 2 AND active card is 7 or 8
	return game_manager.enemy_hp > 2 and (game_manager.active_card == 7 or game_manager.active_card == 8)
