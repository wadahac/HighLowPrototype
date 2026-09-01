extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	is_used = true
	if game_manager.deck.size() < 3:
		game_manager.rebuild_and_reshuffle_deck()
		
	var next_three = [game_manager.deck[0], game_manager.deck[1], game_manager.deck[2]]
	var names = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	var formatted_cards = []
	for card in next_three:
		if card >= 1 and card <= 13:
			formatted_cards.append(names[card])
		else:
			formatted_cards.append(str(card))
			
	if game_manager.vision_label:
		game_manager.vision_label.text = "Vision: " + str(formatted_cards)
	if game_manager.status_label:
		game_manager.status_label.text = "Prophetic Vision activated! Next 3 cards revealed: " + str(next_three)

func execute_enemy(game_manager, enemy_ai) -> void:
	is_used = true
	if game_manager.deck.size() < 3:
		game_manager.rebuild_and_reshuffle_deck()
		
	var next_three = [game_manager.deck[0], game_manager.deck[1], game_manager.deck[2]]
	enemy_ai.vision_peeked_cards = next_three
	enemy_ai.vision_active_this_turn = true
	if game_manager.status_label:
		game_manager.status_label.text = "Enemy activated Prophetic Vision!"

func can_enemy_use(game_manager, _enemy_ai) -> bool:
	if is_used:
		return false
	# Activate if active card is 5, 6, 7, 8, or 9
	return game_manager.active_card >= 5 and game_manager.active_card <= 9
