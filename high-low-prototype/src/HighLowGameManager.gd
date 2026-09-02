extends Node2D

# 1. Custom signals
signal health_changed(player_hp: int, enemy_hp: int)
signal combo_updated(current_combo: int)
signal game_over(winner_name: String)

# 2. Standardized Variables
var player_max_health: int = 10
var player_hp: int = 10
var enemy_max_health: int = 10
var enemy_hp: int = 10
var active_card: int = 0
var shared_pot: int = 0
var current_streak: int = 0
var deck: Array[int] = []
var is_player_turn: bool = true

# Trump Card State
var enemy_cash_out_and_pass_locked: bool = false
var player_cash_out_and_pass_locked: bool = false
var chains_lock_duration: int = 0
var chains_locked_turns: int = 0
var mirror_active: bool = false
var known_future_3rd_card: int = -1
var prophetic_vision_turn_countdown: int = -1

# Reshuffle Tracking Flag
var was_reshuffled_on_last_draw: bool = false

# Trump Instances
var chains_trump = preload("res://src/trumps/ChainsOfFate.gd").new()
var executioner_trump = preload("res://src/trumps/Executioner.gd").new()
var vision_trump = preload("res://src/trumps/PropheticVision.gd").new()
var sacrifice_trump = preload("res://src/trumps/BloodSacrifice.gd").new()
var mirror_trump = preload("res://src/trumps/MirrorShard.gd").new()
var steal_trump = preload("res://src/trumps/SoulThievery.gd").new()

var trumps_hand: Array = []

# 3. @onready variables targeting exact relative paths
@onready var base_card_label: Label = $UI_Layer/Table/BaseCardLabel
@onready var combo_label: Label = $UI_Layer/Table/ComboLabel
@onready var health_label: Label = $UI_Layer/Table/HealthLabel
@onready var turn_label: Label = $UI_Layer/Table/turn
@onready var higher_button: Button = $UI_Layer/ButtonsContainer/HigherButton
@onready var lower_button: Button = $UI_Layer/ButtonsContainer/LowerButton
@onready var cash_out_button: Button = $UI_Layer/ButtonsContainer/CashOutButton
@onready var pass_button: Button = $"UI_Layer/ButtonsContainer/PassButton"
@onready var restart_button: Button = $UI_Layer/ButtonsContainer/RestartButton

# Trump Buttons
@onready var chains_button: Button = $"UI_Layer/TrumpContainer/ChainsButton"
@onready var executioner_button: Button = $"UI_Layer/TrumpContainer/ExecutionerButton"
@onready var vision_button: Button = $"UI_Layer/TrumpContainer/VisionButton"
@onready var sacrifice_button: Button = $"UI_Layer/TrumpContainer/SacrificeButton"
@onready var mirror_button: Button = $"UI_Layer/TrumpContainer/MirrorButton"
@onready var steal_button = $UI_Layer/TrumpContainer/StealButton

# Info Labels
@onready var vision_label: Label = $"UI_Layer/InfoPanel/VisionLabel"
@onready var status_label: Label = $"UI_Layer/InfoPanel/StatusLabel"

@onready var enemy_ai = $EnemyAI

# 4. Initialization and signal connections
func _ready() -> void:
	health_changed.connect(_on_health_changed)
	combo_updated.connect(_on_combo_updated)
	game_over.connect(_on_game_over)
	
	higher_button.pressed.connect(_on_higher_pressed)
	lower_button.pressed.connect(_on_lower_pressed)
	cash_out_button.pressed.connect(_on_cash_out_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	restart_button.pressed.connect(reset_game)
	
	# Connect Trump buttons
	chains_button.pressed.connect(_on_chains_pressed)
	executioner_button.pressed.connect(_on_executioner_pressed)
	vision_button.pressed.connect(_on_vision_pressed)
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	mirror_button.pressed.connect(_on_mirror_pressed)
	steal_button.pressed.connect(_on_steal_button_pressed)
	
	if enemy_ai:
		enemy_ai.decision_made.connect(_on_enemy_decision_made)
	
	restart_button.hide()
	reset_game()
	print("GAME INITIALIZED SUCCESSFULLY")

func reset_game() -> void:
	player_hp = player_max_health
	enemy_hp = enemy_max_health
	shared_pot = 0
	current_streak = 0
	is_player_turn = true
	enemy_cash_out_and_pass_locked = false
	player_cash_out_and_pass_locked = false
	chains_lock_duration = 0
	chains_locked_turns = 0
	mirror_active = false
	known_future_3rd_card = -1
	prophetic_vision_turn_countdown = -1
	was_reshuffled_on_last_draw = false
	
	chains_trump.is_used = false
	executioner_trump.is_used = false
	vision_trump.is_used = false
	sacrifice_trump.is_used = false
	mirror_trump.is_used = false
	steal_trump.is_used = false
	
	trumps_hand = [chains_trump, executioner_trump, vision_trump, sacrifice_trump, mirror_trump]
	
	if vision_label:
		vision_label.text = ""
	if status_label:
		status_label.text = ""
	
	if enemy_ai:
		enemy_ai.reset_deck_memory()
		enemy_ai.reset_trumps()
	
	health_changed.emit(player_hp, enemy_hp)
	combo_updated.emit(shared_pot)
	_update_turn_label()
	
	rebuild_deck()
	active_card = draw_card()
	
	restart_button.hide()
	set_player_controls_enabled(true)
	_update_base_card_ui()

func start_new_match() -> void:
	reset_game()

func restart_match() -> void:
	reset_game()

func rebuild_deck() -> void:
	deck.clear()
	# Strictly 1 through 13 integers
	deck = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
	deck.shuffle()

func rebuild_and_reshuffle_deck() -> void:
	rebuild_deck()
	if active_card in deck:
		deck.erase(active_card)
	known_future_3rd_card = -1
	prophetic_vision_turn_countdown = -1
	print("[DECK] Reshuffled 13-card deck.")
	if status_label:
		status_label.text = "DECK RESHUFFLED! (Strategic 13-card pool refreshed)"

func draw_card() -> int:
	was_reshuffled_on_last_draw = false
	if deck.size() < 3:
		rebuild_and_reshuffle_deck()
		was_reshuffled_on_last_draw = true
	
	var card: int = deck.pop_front()
	
	# Ensure drawn card is not identical to active_card sitting on table
	if card == active_card and not deck.is_empty():
		deck.append(card)
		card = deck.pop_front()
		
	if prophetic_vision_turn_countdown > 0:
		prophetic_vision_turn_countdown -= 1
		if prophetic_vision_turn_countdown == 0 and vision_label:
			vision_label.text = ""
		
	if enemy_ai:
		enemy_ai.record_card_drawn(card)
	return card

func replace_active_card() -> int:
	active_card = draw_card()
	_update_base_card_ui()
	return active_card

# Button handlers
func _on_higher_pressed() -> void:
	if is_player_turn:
		set_player_controls_enabled(false)
		process_guess(true)

func _on_lower_pressed() -> void:
	if is_player_turn:
		set_player_controls_enabled(false)
		process_guess(false)

func _on_cash_out_pressed() -> void:
	if is_player_turn and not player_cash_out_and_pass_locked:
		set_player_controls_enabled(false)
		cash_out()

func _on_pass_pressed() -> void:
	if is_player_turn and not player_cash_out_and_pass_locked:
		set_player_controls_enabled(false)
		if status_label:
			status_label.text = "Player passed the turn."
		switch_turn()

# Reuse Existing UI Buttons (Do NOT Create New Nodes)
func update_trump_ui() -> void:
	refresh_trump_ui()

func refresh_trump_ui() -> void:
	var container = $UI_Layer/TrumpContainer
	if not container:
		return
		
	var buttons = container.get_children()
	var steal_btn = $UI_Layer/TrumpContainer/StealButton
	
	# Filter out steal button
	var trump_buttons = []
	for btn in buttons:
		if btn != steal_btn:
			trump_buttons.append(btn)
			
	# We want to map each unused trump in trumps_hand to a button
	var active_trumps = []
	for t in trumps_hand:
		if not t.is_used:
			active_trumps.append(t)
			
	var assigned_buttons = []
	
	# 1. Try to match by name first
	for trump in active_trumps:
		var trump_name = trump.get_script().get_path().get_file().get_basename()
		var found_btn = null
		for btn in trump_buttons:
			if btn in assigned_buttons:
				continue
			if trump_name.to_lower() in btn.name.to_lower() or btn.name.to_lower() in trump_name.to_lower():
				found_btn = btn
				break
		if found_btn:
			assigned_buttons.append(found_btn)
			_setup_trump_button(found_btn, trump)
			
	# 2. Assign remaining active trumps to any leftover buttons
	for trump in active_trumps:
		var already_assigned = false
		for btn in assigned_buttons:
			if btn.pressed.is_connected(_on_trump_button_pressed.bind(trump)):
				already_assigned = true
				break
		if already_assigned:
			continue
			
		var leftover_btn = null
		for btn in trump_buttons:
			if not btn in assigned_buttons:
				leftover_btn = btn
				break
		if leftover_btn:
			assigned_buttons.append(leftover_btn)
			_setup_trump_button(leftover_btn, trump)
			
	# 3. Hide/disable all unassigned buttons
	for btn in trump_buttons:
		if not btn in assigned_buttons:
			btn.visible = false
			btn.disabled = true
			
	if steal_btn:
		steal_btn.visible = true
		steal_btn.disabled = not is_player_turn

func _setup_trump_button(btn: Button, trump) -> void:
	btn.visible = true
	btn.disabled = not is_player_turn
	var trump_name = trump.get_script().get_path().get_file().get_basename()
	var display_name = trump.card_name if "card_name" in trump else trump_name
	btn.text = display_name
	
	# Clear old connections
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn.callable)
		
	btn.pressed.connect(_on_trump_button_pressed.bind(trump))

func _on_trump_button_pressed(trump) -> void:
	trump.execute_player(self)
	update_trump_ui()
	set_player_controls_enabled(is_player_turn)

# Trump Card Handlers
func _on_chains_pressed() -> void:
	chains_trump.execute_player(self)
	set_player_controls_enabled(true)

func _on_executioner_pressed() -> void:
	executioner_trump.execute_player(self)
	set_player_controls_enabled(true)

func _on_vision_pressed() -> void:
	vision_trump.execute_player(self)
	set_player_controls_enabled(true)

func _on_sacrifice_pressed() -> void:
	sacrifice_trump.execute_player(self)
	set_player_controls_enabled(true)

func _on_mirror_pressed() -> void:
	mirror_trump.execute_player(self)
	set_player_controls_enabled(true)

func _on_steal_button_pressed() -> void:
	var stolen_trump = steal_trump.apply_effect(self, enemy_ai, self)
	if stolen_trump:
		var card_name = stolen_trump.card_name if "card_name" in stolen_trump else stolen_trump.get_script().get_path().get_file().get_basename()
		print("STOLE TRUMP: Stole ", card_name)
		if status_label:
			status_label.text = "Player stole " + card_name + "!"
	else:
		if status_label:
			status_label.text = "Player tried to steal, but enemy has no Trumps!"
	refresh_trump_ui()
	_update_base_card_ui()

func trigger_juice_effect(effect_name: String) -> void:
	print("Juice effect triggered: ", effect_name)
	if status_label:
		status_label.text = "Juice effect: " + effect_name.to_upper()

# AI Decision Handler
func _on_enemy_decision_made(choice: String) -> void:
	if is_player_turn:
		return
	
	if choice == "cash_out":
		cash_out()
	elif choice == "pass":
		if status_label:
			status_label.text = "Enemy passed the turn."
		switch_turn()
	else:
		process_guess(choice == "higher")
	
	if not is_player_turn and player_hp > 0 and enemy_hp > 0:
		if enemy_ai and enemy_ai.can_act:
			enemy_ai.take_turn(active_card, shared_pot, player_hp, enemy_cash_out_and_pass_locked)

# Process guess logic
func process_guess(is_higher: bool) -> void:
	var new_card: int = draw_card()
	var is_reshuffled: bool = was_reshuffled_on_last_draw
	var is_correct: bool = false
	var is_tie: bool = (new_card == active_card)
	
	if is_tie:
		is_correct = true
	elif is_higher and new_card > active_card:
		is_correct = true
	elif not is_higher and new_card < active_card:
		is_correct = true
		
	if is_correct:
		if not is_tie:
			current_streak += 1
			shared_pot += 1
		active_card = new_card
		combo_updated.emit(shared_pot)
		_update_base_card_ui()
		
		if is_reshuffled and status_label:
			var prefix = "Deck reshuffled! " if not status_label.text.begins_with("DECK RESHUFFLED!") else status_label.text + " | "
			if is_player_turn:
				status_label.text = prefix + "Player guessed correctly!"
			else:
				status_label.text = prefix + "Enemy guessed correctly!"

		if not check_game_over():
			if is_player_turn:
				await get_tree().create_timer(1.2).timeout
				set_player_controls_enabled(true)
	else:
		var damage: int = max(1, shared_pot)
		var text_prefix = ""
		if is_reshuffled:
			text_prefix = "DECK RESHUFFLED! "
			
		if is_player_turn:
			if mirror_active:
				var reflected_damage = int(damage * 0.5)
				var self_damage = damage - reflected_damage
				player_hp = max(0, player_hp - self_damage)
				enemy_hp = max(0, enemy_hp - reflected_damage)
				mirror_active = false
				if status_label:
					status_label.text = text_prefix + "Mirror Shard reflected " + str(reflected_damage) + " damage!"
			else:
				player_hp = max(0, player_hp - damage)
				if is_reshuffled and status_label:
					status_label.text = text_prefix + "Player guessed incorrectly!"
		else:
			if mirror_active:
				var reflected_damage = int(damage * 0.5)
				var self_damage = damage - reflected_damage
				enemy_hp = max(0, enemy_hp - self_damage)
				player_hp = max(0, player_hp - reflected_damage)
				mirror_active = false
				if status_label:
					status_label.text = text_prefix + "Mirror Shard reflected " + str(reflected_damage) + " damage!"
			else:
				enemy_hp = max(0, enemy_hp - damage)
				if is_reshuffled and status_label:
					status_label.text = text_prefix + "Enemy guessed incorrectly!"
			
		shared_pot = 0
		current_streak = 0
		active_card = new_card
		
		health_changed.emit(player_hp, enemy_hp)
		combo_updated.emit(shared_pot)
		_update_base_card_ui()
		
		if not check_game_over():
			await get_tree().create_timer(1.2).timeout
			switch_turn()

# Cash out logic
func cash_out() -> void:
	if shared_pot > 0:
		if is_player_turn:
			enemy_hp = max(0, enemy_hp - shared_pot)
		else:
			player_hp = max(0, player_hp - shared_pot)
		shared_pot = 0
		current_streak = 0
		
		health_changed.emit(player_hp, enemy_hp)
		combo_updated.emit(shared_pot)
		_update_base_card_ui()
		
		if not check_game_over():
			await get_tree().create_timer(1.2).timeout
			switch_turn()

func switch_turn() -> void:
	is_player_turn = not is_player_turn
	_update_turn_label()
	
	if chains_lock_duration > 0:
		chains_lock_duration -= 1
		if chains_lock_duration == 0:
			player_cash_out_and_pass_locked = false
			enemy_cash_out_and_pass_locked = false
	
	if is_player_turn:
		mirror_active = false
		set_player_controls_enabled(true)
		if player_cash_out_and_pass_locked and status_label:
			status_label.text = "TRAPPED BY CHAINS OF FATE: YOU MUST GUESS!"
	else:
		set_player_controls_enabled(false)
		
		if enemy_ai:
			# Decrement turns_frozen counter
			if enemy_ai.turns_frozen > 0:
				enemy_ai.turns_frozen -= 1
			if enemy_ai.turns_frozen <= 0:
				enemy_ai.can_act = true
			
			if enemy_ai.can_act:
				enemy_ai.take_turn(active_card, shared_pot, player_hp, enemy_cash_out_and_pass_locked)
			else:
				# If still frozen/cannot act, safely pass turn back to player to avoid hang
				await get_tree().create_timer(1.0).timeout
				switch_turn()

func set_player_controls_enabled(enabled: bool) -> void:
	higher_button.disabled = not enabled
	lower_button.disabled = not enabled
	
	if enabled and is_player_turn:
		cash_out_button.disabled = player_cash_out_and_pass_locked or shared_pot == 0
		pass_button.disabled = player_cash_out_and_pass_locked
		
		# Update Trump buttons state
		refresh_trump_ui()
	else:
		cash_out_button.disabled = true
		pass_button.disabled = true
		chains_button.disabled = true
		executioner_button.disabled = true
		vision_button.disabled = true
		sacrifice_button.disabled = true
		mirror_button.disabled = true
		steal_button.disabled = true

func check_game_over() -> bool:
	if enemy_hp <= 0:
		if status_label:
			status_label.text = "YOU SURVIVED! YOU WIN!"
		_disable_all_controls()
		restart_button.show()
		restart_button.disabled = false
		game_over.emit("Player")
		return true
	elif player_hp <= 0:
		if status_label:
			status_label.text = "YOU DIED! GAME OVER"
		_disable_all_controls()
		restart_button.show()
		restart_button.disabled = false
		game_over.emit("Enemy")
		return true
	return false

func check_game_state() -> bool:
	return check_game_over()

func _disable_all_controls() -> void:
	set_player_controls_enabled(false)
	higher_button.disabled = true
	lower_button.disabled = true
	cash_out_button.disabled = true
	pass_button.disabled = true
	chains_button.disabled = true
	executioner_button.disabled = true
	vision_button.disabled = true
	sacrifice_button.disabled = true
	mirror_button.disabled = true
	steal_button.disabled = true

func _update_base_card_ui() -> void:
	base_card_label.text = str(active_card)

func _update_turn_label() -> void:
	if turn_label:
		if is_player_turn:
			turn_label.text = "YOUR TURN"
		else:
			turn_label.text = "ENEMY TURN"

func _on_health_changed(p_hp: int, e_hp: int) -> void:
	if health_label:
		health_label.text = "Player HP: " + str(p_hp) + " | Enemy HP: " + str(e_hp)

func _on_combo_updated(c_combo: int) -> void:
	if combo_label:
		combo_label.text = "Shared Pot: " + str(c_combo)

func _on_game_over(winner: String) -> void:
	_disable_all_controls()
	restart_button.show()
	restart_button.disabled = false
