extends "res://src/trumps/TrumpCard.gd"

func _vision_is_already_active(game_manager) -> bool:
	return game_manager.vision_owner != "" and game_manager.prophetic_vision_turn_countdown > 0

func execute_player(game_manager) -> void:
	if not can_activate(game_manager):
		return
	if _vision_is_already_active(game_manager):
		if game_manager.status_label:
			game_manager.status_label.text = "A Prophetic Vision is already active!"
		return

	if game_manager.deck.size() < 3:
		game_manager.rebuild_and_reshuffle_deck()

	if game_manager.deck.size() < 3:
		return

	is_used = true
	AudioManager.play_sfx("trump_vision")
	var third_card: int = game_manager.deck[2]
	game_manager.known_future_3rd_card = third_card
	game_manager.prophetic_vision_turn_countdown = 3
	game_manager.vision_owner = "player"
	game_manager.refresh_vision_label()

	var card_str: String = game_manager.get_card_name(third_card)
	if game_manager.status_label:
		game_manager.status_label.text = "Prophetic Vision activated! 3rd card in the future is: " + card_str

func execute_enemy(game_manager, _enemy_ai) -> void:
	if not can_activate(game_manager):
		return
	if _vision_is_already_active(game_manager):
		return

	if game_manager.deck.size() < 3:
		game_manager.rebuild_and_reshuffle_deck()

	if game_manager.deck.size() < 3:
		return

	is_used = true
	AudioManager.play_sfx("trump_vision")
	var third_card: int = game_manager.deck[2]
	game_manager.known_future_3rd_card = third_card
	game_manager.prophetic_vision_turn_countdown = 3
	game_manager.vision_owner = "enemy"

	# The enemy's vision is hidden from the player.
	if game_manager.vision_label:
		game_manager.vision_label.text = ""

	var card_str: String = game_manager.get_card_name(third_card)
	if game_manager.status_label:
		game_manager.status_label.text = "Enemy activated Prophetic Vision! 3rd card in the future is: " + card_str

func can_enemy_use(game_manager, enemy_ai) -> bool:
	if not can_activate(game_manager):
		return false
	if not enemy_ai or not (self in enemy_ai.trumps_hand):
		return false
	if _vision_is_already_active(game_manager):
		return false
	# The AI will draw immediately after activating. If fewer than five cards
	# remain, the predicted (third) card cannot survive the intervening draws.
	if game_manager.deck.size() < 5:
		return false
	# Activate if active card is a risky middle card (5, 6, 7, 8, or 9)
	return game_manager.active_card >= 5 and game_manager.active_card <= 9
