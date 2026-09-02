extends "res://src/trumps/TrumpCard.gd"

func apply_effect(user, target, game_manager) -> void:
	is_used = true
	if target and "trumps_hand" in target and not target.trumps_hand.is_empty():
		var random_index = randi() % target.trumps_hand.size()
		var stolen_card = target.trumps_hand.pop_at(random_index)
		if user and "trumps_hand" in user:
			user.trumps_hand.append(stolen_card)
			print("STOLE TRUMP: Player stole ", stolen_card, " from enemy!")
			
	if game_manager and game_manager.has_method("trigger_juice_effect"):
		game_manager.trigger_juice_effect("steal")
