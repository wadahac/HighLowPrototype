class_name AdvancedEnemyAI
extends Node

signal decision_made(choice: String)

var used_cards: Array[int] = []
var full_deck: Array[int] = []

func _ready() -> void:
	# Initialize full deck with 4 copies of values 1 to 11
	for i in range(1, 12):
		for j in range(4):
			full_deck.append(i)

func reset_deck_memory() -> void:
	used_cards.clear()

func record_card_drawn(card_value: int) -> void:
	used_cards.append(card_value)

func take_turn(current_card_value: int) -> void:
	await get_tree().create_timer(1.5).timeout
	
	# Calculate remaining cards in the deck
	var counts = {}
	for v in range(1, 12):
		counts[v] = 4
		
	for u in used_cards:
		if u in counts:
			counts[u] -= 1
			
	var higher_count: int = 0
	var lower_count: int = 0
	
	for v in range(1, 12):
		var remaining_copies = max(0, counts[v])
		if v > current_card_value:
			higher_count += remaining_copies
		elif v < current_card_value:
			lower_count += remaining_copies
			
	var choice: String = "higher"
	if lower_count > higher_count:
		choice = "lower"
	elif lower_count == higher_count:
		# Tie breaker based on card position
		choice = "higher" if current_card_value <= 6 else "lower"
		
	decision_made.emit(choice)
