extends TrumpCard

func execute_player(game_manager) -> void:
	is_used = true
	if game_manager.deck.size() < 3:
		game_manager.rebuild_deck()
	var future_card = game_manager.deck[game_manager.deck.size() - 3]
	game_manager.vision_label.text = "Future Card (3 turns): " + str(future_card)
	game_manager.status_label.text = "Player activated Prophetic Vision!"

func execute_enemy(game_manager, enemy_ai) -> void:
	is_used = true
	enemy_ai.vision_active_this_turn = true
	game_manager.status_label.text = "Enemy activated Prophetic Vision!"

func can_enemy_use(game_manager, _enemy_ai) -> bool:
	if is_used:
		return false
	# Activate if active card is 5, 6, 7, 8, or 9
	return game_manager.active_card >= 5 and game_manager.active_card <= 9
