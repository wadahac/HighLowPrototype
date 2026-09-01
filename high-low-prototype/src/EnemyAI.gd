class_name AdvancedEnemyAI
extends Node

signal decision_made(choice: String)

var used_cards: Array[int] = []
var full_deck: Array[int] = []

# Enemy single-use Trump card instances
var chains_trump = preload("res://src/trumps/ChainsOfFate.gd").new()
var executioner_trump = preload("res://src/trumps/Executioner.gd").new()
var vision_trump = preload("res://src/trumps/PropheticVision.gd").new()
var sacrifice_trump = preload("res://src/trumps/BloodSacrifice.gd").new()
var mirror_trump = preload("res://src/trumps/MirrorShard.gd").new()

var trumps: Array = []
var vision_active_this_turn: bool = false
var vision_peeked_cards: Array = []

func _ready() -> void:
	trumps = [chains_trump, executioner_trump, vision_trump, sacrifice_trump, mirror_trump]
	# Initialize full deck with 4 copies of values 1 to 13
	for i in range(1, 14):
		for j in range(4):
			full_deck.append(i)

func reset_deck_memory() -> void:
	used_cards.clear()

func reset_trumps() -> void:
	for trump in trumps:
		trump.is_used = false
	vision_active_this_turn = false
	vision_peeked_cards.clear()

func record_card_drawn(card_value: int) -> void:
	used_cards.append(card_value)

func take_turn(current_card_value: int, current_stake: int, player_hp: int, enemy_cash_out_and_pass_locked: bool) -> void:
	# Random delay between 1.0 and 3.0 seconds
	await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
	
	var manager = get_parent()
	if not manager:
		return

	# --- TRUMP CARD EVALUATION (BEFORE PRIMARY ACTION) ---
	for trump in trumps:
		if not trump.is_used and trump.can_enemy_use(manager, self):
			trump.execute_enemy(manager, self)
			if manager.check_game_state():
				return
			if trump == sacrifice_trump:
				# Re-evaluate turn with the new card value
				take_turn(manager.active_card, manager.shared_pot, manager.player_hp, enemy_cash_out_and_pass_locked)
				return

	# Update local variables in case they changed from Trumps
	current_card_value = manager.active_card
	current_stake = manager.shared_pot

	# Lethal Cash-Out Check (only if not locked)
	if not enemy_cash_out_and_pass_locked and current_stake >= player_hp and current_stake > 0:
		decision_made.emit("cash_out")
		return
	
	# Determine if we want to Pass (only if not locked)
	var should_pass: bool = false
	if should_pass and not enemy_cash_out_and_pass_locked:
		# Chains of Fate check right before passing
		if not chains_trump.is_used and chains_trump.can_enemy_use(manager, self):
			chains_trump.execute_enemy(manager, self)
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
		if current_card_value <= 7:
			optimal_choice = "higher"
			worse_choice = "lower"
		else:
			optimal_choice = "lower"
			worse_choice = "higher"
			
	var choice: String = optimal_choice

	if vision_active_this_turn and not vision_peeked_cards.is_empty():
		vision_active_this_turn = false
		var next_card = vision_peeked_cards[0]
		vision_peeked_cards.clear()
		if next_card > current_card_value:
			choice = "higher"
		elif next_card < current_card_value:
			choice = "lower"
		else:
			choice = optimal_choice
	else:
		# Determine final choice with a 35% mistake chance
		if randf() < 0.35:
			choice = worse_choice
		
	decision_made.emit(choice)
