class_name AdvancedEnemyAI
extends Node

signal decision_made(choice: String)

var used_cards: Array[int] = []
var vision_active: bool = false

# Turn freeze / lock state
var can_act: bool = true
var turns_frozen: int = 0

# Enemy single-use Trump card instances
var chains_trump = preload("res://src/trumps/ChainsOfFate.gd").new()
var executioner_trump = preload("res://src/trumps/Executioner.gd").new()
var vision_trump = preload("res://src/trumps/PropheticVision.gd").new()
var sacrifice_trump = preload("res://src/trumps/BloodSacrifice.gd").new()
var mirror_trump = preload("res://src/trumps/MirrorShard.gd").new()

var trumps: Array = []
var trumps_hand: Array = []

func _ready() -> void:
	trumps = [chains_trump, executioner_trump, vision_trump, sacrifice_trump, mirror_trump]
	trumps_hand = [chains_trump, executioner_trump, vision_trump, sacrifice_trump, mirror_trump]

func reset_deck_memory() -> void:
	used_cards.clear()

func reset_trumps() -> void:
	for trump in trumps:
		trump.is_used = false
	trumps_hand = [chains_trump, executioner_trump, vision_trump, sacrifice_trump, mirror_trump]
	vision_active = false
	can_act = true
	turns_frozen = 0

func record_card_drawn(card_value: int) -> void:
	used_cards.append(card_value)

func take_turn(current_card_value: int, current_stake: int, player_hp: int, enemy_cash_out_and_pass_locked: bool) -> void:
	# Random delay between 1.0 and 3.0 seconds
	await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
	
	var manager = get_parent()
	if not manager:
		return

	current_card_value = manager.active_card
	current_stake = manager.shared_pot

	# --- EXACT PROBABILITY CALCULATION (CARD COUNTING) ---
	var higher_count: int = 0
	var lower_count: int = 0
	var total_remaining: int = manager.deck.size()

	for card in manager.deck:
		if card > current_card_value:
			higher_count += 1
		elif card < current_card_value:
			lower_count += 1

	var higher_prob: float = float(higher_count) / float(max(1, total_remaining))
	var lower_prob: float = float(lower_count) / float(max(1, total_remaining))

	# --- FORCE AI DECISION LOCK ---
	if manager.enemy_cash_out_and_pass_locked:
		print("AI is CHAINED: Bypassing cash out/pass decisions. Forcing guess.")
		var choose_higher = higher_prob >= lower_prob
		manager.process_guess(choose_higher)
		return

	var best_choice: String = "higher"
	var best_prob: float = higher_prob

	if lower_prob > higher_prob:
		best_choice = "lower"
		best_prob = lower_prob
	elif lower_prob == higher_prob:
		if current_card_value <= 7:
			best_choice = "higher"
			best_prob = higher_prob
		else:
			best_choice = "lower"
			best_prob = lower_prob

	# --- DEBUFF CHECK (FORCE GUESSING IMMEDIATELY) ---
	if manager.enemy_cash_out_and_pass_locked or manager.chains_lock_duration > 0 or enemy_cash_out_and_pass_locked:
		if manager.status_label:
			manager.status_label.text = "Enemy locked by Chains of Fate! Calculates %d%% win rate and guesses %s!" % [int(best_prob * 100), best_choice.to_upper()]
		decision_made.emit(best_choice)
		return

	var is_bad_card: bool = (current_card_value in [5, 6, 7, 8]) or (best_prob < 0.60)

	# --- PROPHETIC VISION ADVANTAGE ---
	if manager.prophetic_vision_turn_countdown == 0 and manager.known_future_3rd_card != -1:
		var future_card = manager.known_future_3rd_card
		var vision_choice: String = best_choice
		if future_card > current_card_value:
			vision_choice = "higher"
		elif future_card < current_card_value:
			vision_choice = "lower"
		
		if manager.status_label:
			manager.status_label.text = "Enemy uses Prophetic Vision foresight (100%% win rate) and guesses %s!" % vision_choice.to_upper()
		manager.known_future_3rd_card = -1
		decision_made.emit(vision_choice)
		return

	# --- STRATEGIC TRUMP & DECISION TREE ---
	# Lethal Cash-Out Check
	if current_stake >= player_hp and current_stake > 0:
		if manager.status_label:
			manager.status_label.text = "Enemy sees lethal cash-out! Cashes out to win!"
		decision_made.emit("cash_out")
		return

	# Bad Cards / Low Win % Strategic Responses
	if is_bad_card:
		# Chains of Fate + Pass
		if not chains_trump.is_used and chains_trump.can_enemy_use(manager, self):
			chains_trump.execute_enemy(manager, self)
			if manager.status_label:
				manager.status_label.text = "Enemy plays Chains of Fate and PASSES on a risky %d!" % current_card_value
			decision_made.emit("pass")
			return

		# Blood Sacrifice to replace bad active card
		if not sacrifice_trump.is_used and manager.enemy_hp > 4 and sacrifice_trump.can_enemy_use(manager, self):
			sacrifice_trump.execute_enemy(manager, self)
			take_turn(manager.active_card, manager.shared_pot, manager.player_hp, enemy_cash_out_and_pass_locked)
			return

		# Mirror Shard protection before taking a risky guess
		if not mirror_trump.is_used and mirror_trump.can_enemy_use(manager, self):
			mirror_trump.execute_enemy(manager, self)

		# Cash out to protect existing pot
		if current_stake >= 4:
			if manager.status_label:
				manager.status_label.text = "Enemy plays safe on a bad card and cashes out pot of %d!" % current_stake
			decision_made.emit("cash_out")
			return

	# Offensive Trumps for Good Cards / High Win %
	if best_prob >= 0.60:
		if not executioner_trump.is_used and current_stake >= 3 and executioner_trump.can_enemy_use(manager, self):
			executioner_trump.execute_enemy(manager, self)

		if not vision_trump.is_used and vision_trump.can_enemy_use(manager, self):
			vision_trump.execute_enemy(manager, self)

	# --- FINAL DECISION EMISSION ---
	if manager.status_label:
		manager.status_label.text = "Enemy calculates %d%% win rate and guesses %s!" % [int(best_prob * 100), best_choice.to_upper()]
	decision_made.emit(best_choice)
