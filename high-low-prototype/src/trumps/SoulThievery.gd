extends "res://src/trumps/TrumpCard.gd"

func apply_effect(user, target, game_manager) -> Variant:
	is_used = true
	var stolen_card = null
	if target and "trumps_hand" in target and not target.trumps_hand.is_empty():
		# Prefer stealing an unused trump card if available
		var unused_trumps = []
		for t in target.trumps_hand:
			if not t.is_used:
				unused_trumps.append(t)
		
		if not unused_trumps.is_empty():
			var random_index = randi() % unused_trumps.size()
			stolen_card = unused_trumps[random_index]
			target.trumps_hand.erase(stolen_card)
		else:
			var random_index = randi() % target.trumps_hand.size()
			stolen_card = target.trumps_hand.pop_at(random_index)
		
		if stolen_card:
			stolen_card.is_used = false # Ensure the stolen card is active and usable for the player
			if user and "trumps_hand" in user:
				user.trumps_hand.append(stolen_card)
			
	if game_manager and game_manager.has_method("trigger_juice_effect"):
		game_manager.trigger_juice_effect("steal")
	return stolen_card
