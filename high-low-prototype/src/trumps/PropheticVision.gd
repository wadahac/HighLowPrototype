extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	is_used = true
	if game_manager.deck.size() < 3:
		game_manager.rebuild_and_reshuffle_deck()
		
	var third_card = game_manager.deck[2]
	game_manager.known_future_3rd_card = third_card
	game_manager.prophetic_vision_turn_countdown = 3
	
	var names = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	var card_str = names[third_card] if (third_card >= 1 and third_card <= 13) else str(third_card)
			
	if game_manager.vision_label:
		game_manager.vision_label.text = "Vision 3rd: " + card_str
	if game_manager.status_label:
		game_manager.status_label.text = "Prophetic Vision activated! 3rd card in the future is: " + card_str

func execute_enemy(game_manager, enemy_ai) -> void:
	is_used = true
	if game_manager.deck.size() < 3:
		game_manager.rebuild_and_reshuffle_deck()
		
	var third_card = game_manager.deck[2]
	game_manager.known_future_3rd_card = third_card
	game_manager.prophetic_vision_turn_countdown = 3
	enemy_ai.vision_active = true
	
	var names = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	var card_str = names[third_card] if (third_card >= 1 and third_card <= 13) else str(third_card)
	
	if game_manager.status_label:
		game_manager.status_label.text = "Enemy activated Prophetic Vision! 3rd card in the future is: " + card_str

func can_enemy_use(game_manager, _enemy_ai) -> bool:
	if is_used:
		return false
	# Activate if active card is a risky middle card (5, 6, 7, 8, or 9)
	return game_manager.active_card >= 5 and game_manager.active_card <= 9
