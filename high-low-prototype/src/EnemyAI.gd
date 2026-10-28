class_name AdvancedEnemyAI
extends Node

signal decision_made(choice: String)

var used_cards: Array[int] = []

# Execution guard and stale-turn protection
var is_thinking: bool = false
var turn_serial: int = 0

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
	turn_serial += 1
	is_thinking = false

func record_card_drawn(card_value: int) -> void:
	used_cards.append(card_value)

# A trump is usable by the AI only while it is actually in the AI's hand.
# Soul Thievery removes the instance from trumps_hand, so a stolen card can
# never be used by the enemy even though the instance still exists.
func _is_trump_available(trump) -> bool:
	return trump in trumps_hand and not trump.is_used

func _finish_turn(serial: int) -> void:
	if serial == turn_serial:
		is_thinking = false

func _finish_and_emit(serial: int, choice: String) -> void:
	if serial != turn_serial:
		return
	is_thinking = false
	decision_made.emit(choice)

func take_turn() -> void:
	if is_thinking:
		return

	var manager = get_parent()
	if not manager:
		return
	if manager.is_game_over or manager.is_player_turn:
		return

	turn_serial += 1
	var serial: int = turn_serial
	var started_match: int = manager.match_id
	is_thinking = true

	# Random delay between 1.0 and 3.0 seconds
	await get_tree().create_timer(randf_range(1.0, 3.0)).timeout

	if not is_instance_valid(manager) or serial != turn_serial:
		return
	if manager.match_id != started_match or manager.is_game_over or manager.is_player_turn:
		_finish_turn(serial)
		return

	var current_card_value: int = manager.active_card
	var current_stake: int = manager.shared_pot

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

	# --- PROPHETIC VISION ADVANTAGE ---
	# The AI may only use its own vision, and only when the predicted card is
	# literally the next card (countdown == 1). The deck must also be large
	# enough that the next draw will not trigger a reshuffle first.
	var vision_choice: String = ""
	if manager.vision_owner == "enemy" \
			and manager.prophetic_vision_turn_countdown == 1 \
			and manager.known_future_3rd_card != -1 \
			and manager.deck.size() >= 3:
		var future_card: int = manager.known_future_3rd_card
		vision_choice = best_choice
		if future_card > current_card_value:
			vision_choice = "higher"
		elif future_card < current_card_value:
			vision_choice = "lower"

		manager.known_future_3rd_card = -1
		manager.prophetic_vision_turn_countdown = -1
		manager.vision_owner = ""
		manager.refresh_vision_label()

	# If the AI knows the exact next card, take the guaranteed guess before
	# spending any other trumps.
	if vision_choice != "":
		manager.set_status("Enemy uses Prophetic Vision foresight (100% win rate) and guesses " + vision_choice.to_upper() + "!", "bad")
		_finish_and_emit(serial, vision_choice)
		return

	# --- STRATEGIC TRUMP & DECISION TREE ---
	# Lethal Cash-Out Check (not allowed while chained)
	if not manager.enemy_cash_out_and_pass_locked \
			and current_stake >= manager.player_hp \
			and current_stake > 0:
		manager.set_status("Enemy sees lethal cash-out! Cashes out to win!", "bad")
		_finish_and_emit(serial, "cash_out")
		return

	var is_bad_card: bool = (current_card_value in [5, 6, 7, 8]) or (best_prob < 0.60)
	var used_trump: bool = false

	# Bad Cards / Low Win % Strategic Responses
	if is_bad_card:
		# Chains of Fate + Pass
		if not manager.enemy_cash_out_and_pass_locked \
				and _is_trump_available(chains_trump) \
				and chains_trump.can_enemy_use(manager, self):
			chains_trump.execute_enemy(manager, self)
			if manager.is_game_over:
				_finish_turn(serial)
				return
			used_trump = true
			manager.set_status("Enemy plays Chains of Fate and PASSES on a risky %d!" % current_card_value, "chain")
			_finish_and_emit(serial, "pass")
			return

		# Cash out to protect existing pot BEFORE spending Blood Sacrifice.
		# Cash out is illegal while chained, so the AI must still guess then.
		if not manager.enemy_cash_out_and_pass_locked and current_stake >= 4:
			manager.set_status("Enemy plays safe on a bad card and cashes out pot of %d!" % current_stake, "warn")
			_finish_and_emit(serial, "cash_out")
			return

		# Blood Sacrifice to replace bad active card
		if _is_trump_available(sacrifice_trump) and manager.enemy_hp > 4 and sacrifice_trump.can_enemy_use(manager, self):
			sacrifice_trump.execute_enemy(manager, self)
			if manager.is_game_over:
				_finish_turn(serial)
				return
			used_trump = true

			# Update local variables to match the newly drawn card and continue execution
			current_card_value = manager.active_card
			current_stake = manager.shared_pot

			higher_count = 0
			lower_count = 0
			total_remaining = manager.deck.size()
			for card in manager.deck:
				if card > current_card_value:
					higher_count += 1
				elif card < current_card_value:
					lower_count += 1
			higher_prob = float(higher_count) / float(max(1, total_remaining))
			lower_prob = float(lower_count) / float(max(1, total_remaining))

			best_choice = "higher"
			best_prob = higher_prob
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
			is_bad_card = (current_card_value in [5, 6, 7, 8]) or (best_prob < 0.60)

		# Mirror Shard protection is only useful if a risky guess remains.
		if is_bad_card and _is_trump_available(mirror_trump) and mirror_trump.can_enemy_use(manager, self):
			mirror_trump.execute_enemy(manager, self)
			if manager.is_game_over:
				_finish_turn(serial)
				return
			used_trump = true

	# Offensive Trumps for Good Cards / High Win %
	if best_prob >= 0.60:
		if _is_trump_available(executioner_trump) and current_stake >= 3 and executioner_trump.can_enemy_use(manager, self):
			executioner_trump.execute_enemy(manager, self)
			if manager.is_game_over:
				_finish_turn(serial)
				return
			used_trump = true

		if _is_trump_available(vision_trump) and vision_trump.can_enemy_use(manager, self):
			vision_trump.execute_enemy(manager, self)
			if manager.is_game_over:
				_finish_turn(serial)
				return
			used_trump = true

	# --- FINAL DECISION EMISSION ---
	if manager.enemy_cash_out_and_pass_locked:
		manager.set_status("Enemy is chained and cannot cash out or pass. Guesses %s!" % best_choice.to_upper(), "chain")
	elif not used_trump:
		manager.set_status("Enemy calculates %d%% win rate and guesses %s!" % [int(best_prob * 100), best_choice.to_upper()], "muted")
	_finish_and_emit(serial, best_choice)
