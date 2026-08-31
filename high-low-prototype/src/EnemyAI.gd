class_name AdvancedEnemyAI
extends Node

signal decision_made(choice: String)

var used_cards: Array[int] = []
var full_deck: Array[int] = []

func _ready() -> void:
	# Initialize full deck with 4 copies of values 1 to 13
	for i in range(1, 14):
		for j in range(4):
			full_deck.append(i)

func reset_deck_memory() -> void:
	used_cards.clear()

func record_card_drawn(card_value: int) -> void:
	used_cards.append(card_value)

func take_turn(current_card_value: int, current_stake: int, player_hp: int, enemy_cash_out_locked: bool) -> void:
	# Random delay between 1.0 and 3.0 seconds
	await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
	
	# Lethal Cash-Out Check (only if not locked)
	if not enemy_cash_out_locked and current_stake >= player_hp and current_stake > 0:
		decision_made.emit("cash_out")
		return
	
	# If cash out is locked, evaluate if we should Pass based on card probability
	if enemy_cash_out_locked:
		if current_card_value >= 6 and current_card_value <= 8:
			decision_made.emit("pass")
			return
	
	# Calculate remaining cards in the deck
	var counts = {}
	for v in range(1, 14):
		counts[v] = 4
		
	for u in used_cards:
		if u in counts:
			counts[u] -= 1
			
	var higher_count: int = 0
	var lower_count: int = 0
	
	for v in range(1, 14):
		var remaining_copies = max(0, counts[v])
		if v > current_card_value:
			higher_count += remaining_copies
		elif v < current_card_value:
			lower_count += remaining_copies
			
	var optimal_choice: String = "higher"
	var worse_choice: String = "lower"
	
	if lower_count > higher_count:
		optimal_choice = "lower"
		worse_choice = "higher"
	elif lower_count == higher_count:
		# Tie breaker based on card position
		if current_card_value <= 7:
			optimal_choice = "higher"
			worse_choice = "lower"
		else:
			optimal_choice = "lower"
			worse_choice = "higher"
			
	# Determine final choice with a 35% mistake chance
	var choice: String = optimal_choice
	if randf() < 0.35:
		choice = worse_choice
		
	decision_made.emit(choice)
