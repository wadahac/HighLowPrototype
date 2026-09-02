extends "res://src/trumps/TrumpCard.gd"

func apply_effect(user, target, game_manager) -> Variant:
	is_used = true
	var stolen_card = null
	if target and "trumps_hand" in target and not target.trumps_hand.is_empty():
		var random_index = randi() % target.trumps_hand.size()
		stolen_card = target.trumps_hand.pop_at(random_index)
		if user and "trumps_hand" in user:
			user.trumps_hand.append(stolen_card)
			
	if game_manager and game_manager.has_method("trigger_juice_effect"):
		game_manager.trigger_juice_effect("steal")
	return stolen_card
