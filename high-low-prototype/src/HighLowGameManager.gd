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
var mirror_active: bool = false

# Trump Instances
var chains_trump = preload("res://src/trumps/ChainsOfFate.gd").new()
var executioner_trump = preload("res://src/trumps/Executioner.gd").new()
var vision_trump = preload("res://src/trumps/PropheticVision.gd").new()
var sacrifice_trump = preload("res://src/trumps/BloodSacrifice.gd").new()
var mirror_trump = preload("res://src/trumps/MirrorShard.gd").new()

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
	restart_button.pressed.connect(restart_match)
	
	# Connect Trump buttons
	chains_button.pressed.connect(_on_chains_pressed)
	executioner_button.pressed.connect(_on_executioner_pressed)
	vision_button.pressed.connect(_on_vision_pressed)
	sacrifice_button.pressed.connect(_on_sacrifice_pressed)
	mirror_button.pressed.connect(_on_mirror_pressed)
	
	if enemy_ai:
		enemy_ai.decision_made.connect(_on_enemy_decision_made)
	
	restart_button.hide()
	start_new_match()
	_update_base_card_ui()
	print("GAME INITIALIZED SUCCESSFULLY")

func start_new_match() -> void:
	player_hp = player_max_health
	enemy_hp = enemy_max_health
	shared_pot = 0
	current_streak = 0
	is_player_turn = true
	enemy_cash_out_and_pass_locked = false
	player_cash_out_and_pass_locked = false
	mirror_active = false
	
	chains_trump.is_used = false
	executioner_trump.is_used = false
	vision_trump.is_used = false
	sacrifice_trump.is_used = false
	mirror_trump.is_used = false
	
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
	
	set_player_controls_enabled(true)
	_update_base_card_ui()

func restart_match() -> void:
	restart_button.hide()
	start_new_match()

func rebuild_deck() -> void:
	deck.clear()
	# Generate a full 52-card deck (4 copies of values 1 to 13)
	for i in range(1, 14):
		for j in range(4):
			deck.append(i)
	deck.shuffle()

func draw_card() -> int:
	if deck.size() < 3:
		rebuild_deck()
		status_label.text = "Deck reshuffled with fresh cards!"
	
	var card_index = deck.size() - 1
	var card = deck[card_index]
	
	# Ensure the next drawn card value is NEVER identical to active_card
	if card == active_card:
		var found_alternative = false
		for i in range(deck.size() - 2, -1, -1):
			if deck[i] != active_card:
				# Swap the identical card with a unique one deeper in the deck
				var temp = deck[i]
				deck[i] = deck[card_index]
				deck[card_index] = temp
				card = deck[card_index]
				found_alternative = true
				break
		
		# If no alternative is found (e.g. all remaining cards are identical), rebuild early
		if not found_alternative:
			rebuild_deck()
			status_label.text = "Deck reshuffled with fresh cards!"
			return draw_card()
			
	deck.pop_back()
	if enemy_ai:
		enemy_ai.record_card_drawn(card)
	return card

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
		status_label.text = "Player passed the turn."
		switch_turn()

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

# AI Decision Handler
func _on_enemy_decision_made(choice: String) -> void:
	if is_player_turn:
		return
	
	if choice == "cash_out":
		cash_out()
	elif choice == "pass":
		status_label.text = "Enemy passed the turn."
		switch_turn()
	else:
		process_guess(choice == "higher")
	
	if not is_player_turn and player_hp > 0 and enemy_hp > 0:
		enemy_ai.take_turn(active_card, shared_pot, player_hp, enemy_cash_out_and_pass_locked)

# Process guess logic
func process_guess(is_higher: bool) -> void:
	var new_card: int = draw_card()
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
			shared_pot += int(pow(2, current_streak - 1))
		active_card = new_card
		combo_updated.emit(shared_pot)
		_update_base_card_ui()
		if not check_game_state():
			if is_player_turn:
				await get_tree().create_timer(1.2).timeout
				set_player_controls_enabled(true)
	else:
		var damage: int = max(1, shared_pot)
		if is_player_turn:
			if mirror_active:
				var reflected_damage = int(damage * 0.5)
				var self_damage = damage - reflected_damage
				player_hp = max(0, player_hp - self_damage)
				enemy_hp = max(0, enemy_hp - reflected_damage)
				mirror_active = false
				status_label.text = "Mirror Shard reflected " + str(reflected_damage) + " damage!"
			else:
				player_hp = max(0, player_hp - damage)
		else:
			if mirror_active:
				var reflected_damage = int(damage * 0.5)
				var self_damage = damage - reflected_damage
				enemy_hp = max(0, enemy_hp - self_damage)
				player_hp = max(0, player_hp - reflected_damage)
				mirror_active = false
				status_label.text = "Mirror Shard reflected " + str(reflected_damage) + " damage!"
			else:
				enemy_hp = max(0, enemy_hp - damage)
			
		shared_pot = 0
		current_streak = 0
		active_card = new_card
		
		health_changed.emit(player_hp, enemy_hp)
		combo_updated.emit(shared_pot)
		_update_base_card_ui()
		
		if not check_game_state():
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
		
		if not check_game_state():
			await get_tree().create_timer(1.2).timeout
			switch_turn()

func switch_turn() -> void:
	is_player_turn = not is_player_turn
	_update_turn_label()
	if is_player_turn:
		vision_label.text = ""
		mirror_active = false
		enemy_cash_out_and_pass_locked = false
		set_player_controls_enabled(true)
		if player_cash_out_and_pass_locked:
			status_label.text = "TRAPPED BY CHAINS OF FATE: YOU MUST GUESS!"
	else:
		player_cash_out_and_pass_locked = false
		set_player_controls_enabled(false)
		if enemy_ai:
			enemy_ai.take_turn(active_card, shared_pot, player_hp, enemy_cash_out_and_pass_locked)

func set_player_controls_enabled