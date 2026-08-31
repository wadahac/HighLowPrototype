class_name AdvancedEnemyAI
extends Node

signal decision_made(choice: String)

var used_cards: Array[int] = []
var full_deck: Array[int] = []

# Enemy single-use Trump card tracking
var enemy_chains_used: bool = false
var enemy_executioner_used: bool = false
var enemy_vision_used: bool = false
var enemy_sacrifice_used: bool = false
var enemy_mirror_used: bool = false

func _ready() -> void:
	# Initialize full deck with 4 copies of values 1 to 13
	for i in range(1, 14):
		for j in range(4):
			full_deck.append(i)

func reset_deck_memory() -> void:
	used_cards.clear()

func reset_trumps() -> void:
	enemy_chains_used = false
	enemy_executioner_used = false
	enemy_vision_used = false
	enemy_sacrifice_used = false
	enemy_mirror_used = false

func record_card_drawn(card_value: int) -> void:
	used_cards.append(card_value)

func take_turn(current_card_value: int, current_stake: int, player_hp: int, enemy_cash_out_locked: bool) -> void:
	# Random delay between 1.0 and 3.0 seconds
	await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
	
	var manager = get_parent()
	if not manager:
		return

	# --- TRUMP CARD EVALUATION (BEFORE PRIMARY ACTION) ---
	
	# 1. Executioner: Activate if shared pot >= 4
	if not enemy_executioner_used and manager.current_combo_damage >= 4:
		enemy_executioner_used = true
		var dmg = int(manager.current_combo_damage * 0.5)
		manager.player_current_health = max(0, manager.player_current_health - dmg)
		manager.current_combo_damage -= dmg
		manager.health_changed.emit(manager.player_current_health, manager.enemy_current_health)
		manager.combo_updated.emit(manager.current_combo_damage)
		manager.status_label.text = "Enemy used Executioner! Dealt " + str(dmg) + " damage!"
		if manager.check_game_state():
			return

	# 2. Blood Sacrifice: Activate if Enemy HP > 5 AND active card is 7 or 8
	if not enemy_sacrifice_used and manager.enemy_current_health > 5 and (manager.current_base_value == 7 or manager.current_base_value == 8):
		enemy_sacrifice_used = true
		manager.enemy_current_health = max(0, manager.enemy_current_health - 2)
		manager.current_base_value = manager.draw_card()
		manager.health_changed.emit(manager.player_current_health, manager.enemy_current_health)
		manager._update_base_card_ui()
		manager.status_label.text = "Enemy used Blood Sacrifice! Card replaced."
		if manager.check_game_state():
			return
		# Re-evaluate turn with the new card value
		take_turn(manager.current_base_value, manager.current_combo_damage, manager.player_current_health, enemy_cash_out_locked)
		return

	# Update local variables in case they changed from Trumps
	current_card_value = manager.current_base_value
	current_stake = manager.current_combo_damage

	# Lethal Cash-Out Check (only if not locked)
	if not enemy_cash_out_locked and current_stake >= player_hp and current_stake > 0:
		decision_made.emit("cash_out")
		return
	
	# Determine if we want to Pass
	var should_pass: bool = false
	if enemy_cash_out_locked:
		if current_card_value >= 6 and current_card_value <= 8:
			should_pass = true

	if should_pass:
		# 5. Chains of Fate: Activate right before passing turn if shared pot >= 3 and active card is 7 or 8
		if not enemy_chains_used and current_stake >= 3 and (current_card_value == 7 or current_card_value == 8):
			enemy_chains_used = true
			manager.player_cash_out_locked = true
			manager.status_label.text = "Enemy used Chains of Fate! Player cannot cash out next turn."
		decision_made.emit("pass")
		return

	# 3. Prophetic Vision: Activate if active card is 5, 6, 7, 8, or 9
	var vision_active: bool = false
	if not enemy_vision_used and (current_card_value >= 5 and current_card_value <= 9):
		enemy_vision_used = true
		vision_active = true
		manager.status_label.text = "Enemy used Prophetic Vision!"

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

	if vision_active:
		# Guaranteed correct choice using Prophetic Vision
		if manager.deck.is_empty():
			manager.rebuild_deck()
		var next_card = manager.deck[manager.deck.size() - 1]
		if next_card > current_card_value:
			choice = "higher"
		elif next_card < current_card_value:
			choice = "lower"
		else:
			choice = optimal_choice
	else:
		# 4. Mirror Shard: Activate before taking a High/Low guess with ~50% success probability (card is 6, 7, 8)
		if not enemy_mirror_used and (current_card_value >= 6 and current_card_value <= 8):
			enemy_mirror_used = true
			manager.mirror_active = true
			manager.status_label.text = "Enemy used Mirror Shard!"
		
		# Determine final choice with a 35% mistake chance
		if randf() < 0.35:
			choice = worse_choice
		
	decision_made.emit(choice)
