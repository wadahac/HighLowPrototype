extends "res://src/trumps/TrumpCard.gd"

func apply_effect(user, target, game_manager) -> Variant:
	if not can_activate(game_manager):
		return null
	if not target or not ("trumps_hand" in target) or target.trumps_hand.is_empty():
		if game_manager.status_label:
			game_manager.status_label.text = "No enemy Trumps available to steal!"
		return null

	# Prefer stealing an unused trump card if available
	var unused_trumps: Array = []
	for t in target.trumps_hand:
		if not t.is_used:
			unused_trumps.append(t)

	var stolen_card = null
	if not unused_trumps.is_empty():
		var random_index: int = randi() % unused_trumps.size()
		stolen_card = unused_trumps[random_index]
		target.trumps_hand.erase(stolen_card)
	else:
		var random_index: int = randi() % target.trumps_hand.size()
		stolen_card = target.trumps_hand.pop_at(random_index)

	if not stolen_card:
		return null

	is_used = true
	AudioManager.play_sfx("trump_thievery")
	stolen_card.is_used = false # Ensure the stolen card is active and usable for the player
	if user and "trumps_hand" in user:
		user.trumps_hand.append(stolen_card)

	if game_manager and game_manager.has_method("trigger_juice_effect"):
		game_manager.trigger_juice_effect("steal")
	return stolen_card
