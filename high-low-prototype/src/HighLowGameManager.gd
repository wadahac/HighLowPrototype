extends Node2D

# 1. Custom signals
signal health_changed(player_hp: int, enemy_hp: int)
signal combo_updated(current_combo: int)
signal game_over(winner_name: String)

# 2. Variables
var player_max_health: int = 10
var player_current_health: int = 10
var enemy_max_health: int = 10
var enemy_current_health: int = 10
var current_base_value: int = 0
var current_combo_damage: int = 0
var current_streak: int = 0
var deck: Array[int] = []
var is_player_turn: bool = true

# Trump Card State
var enemy_cash_out_locked: bool = false
var player_cash_out_locked: bool = false
var mirror_active: bool = false

var chains_used: bool = false
var executioner_used: bool = false
var vision_used: bool = false
var sacrifice_used: bool = false
var mirror_used: bool = false

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
	# Connect custom signals to helper functions
	health_changed.connect(_on_health_changed)
	combo_updated.connect(_on_combo_updated)
	game_over.connect(_on_game_over)
	
	# Connect button pressed signals directly to gameplay functions
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
	
	# Hide restart button initially
	restart_button.hide()
	
	# Initialize game state
	start_new_match()
	
	# Manually call initial label text draw update so the first card is visible immediately
	_update_base_card_ui()
	
	print("GAME INITALIZED SUCCESFULLY")

func start_new_match() -> void:
	player_current_health = player_max_health
	enemy_current_health = enemy_max_health
	current_combo_damage = 0
	current_streak = 0
	is_player_turn = true
	enemy_cash_out_locked = false
	player_cash_out_locked = false
	mirror_active = false
	
	chains_used = false
	executioner_used = false
	vision_used = false
	sacrifice_used = false
	mirror_used = false
	
	if vision_label:
		vision_label.text = ""
	if status_label:
		status_label.text = ""
	
	if enemy_ai:
		enemy_ai.reset_deck_memory()
		enemy_ai.reset_trumps()
	
	# Explicitly invoke the setup updates right after setting base variables
	health_changed.emit(player_current_health, enemy_current_health)
	combo_updated.emit(current_combo_damage)
	_update_turn_label()
	
	rebuild_deck()
	current_base_value = draw_card()
	
	set_player_controls_enabled(true)
	_update_base_card_ui()

func restart_match() -> void:
	restart_button.hide()
	start_new_match()

func rebuild_deck() -> void:
	deck.clear()
	for i in range(1, 14):
		deck.append(i)
	deck.shuffle()

func draw_card() -> int:
	if deck.is_empty():
		rebuild_deck()
	var card = deck.pop_back()
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
	if is_player_turn:
		set_player_controls_enabled(false)
		cash_out()

func _on_pass_pressed() -> void:
	if is_player_turn:
		set_player_controls_enabled(false)
		status_label.text = "Player passed the turn."
		switch_turn()

# Trump Card Handlers
func _on_chains_pressed() -> void:
	chains_used = true
	chains_button.disabled = true
	enemy_cash_out_locked = true
	status_label.text = "Player used Chains of Fate! Enemy cannot cash out next turn."

func _on_executioner_pressed() -> void:
	executioner_used = true
	executioner_button.disabled = true
	var dmg = int(current_combo_damage * 0.5)
	enemy_current_health = max(0, enemy_current_health - dmg)
	current_combo_damage -= dmg
	health_changed.emit(player_current_health, enemy_current_health)
	combo_updated.emit(current_combo_damage)
	status_label.text = "Player used Executioner! Dealt " + str(dmg) + " damage!"
	check_game_state()

func _on_vision_pressed() -> void:
	vision_used = true
	vision_button.disabled = true
	while deck.size() < 3:
		var temp_deck: Array[int] = []
		for i in range(1, 14):
			temp_deck.append(i)
		temp_deck.shuffle()
		deck = temp_deck + deck
	var future_card = deck[deck.size() - 3]
	vision_label.text = "Future Card (3 turns): " + str(future_card)
	status_label.text = "Player used Prophetic Vision!"

func _on_sacrifice_pressed() -> void:
	sacrifice_used = true
	sacrifice_button.disabled = true
	player_current_health = max(0, player_current_health - 2)
	current_base_value = draw_card()
	health_changed.emit(player_current_health, enemy_current_health)
	_update_base_card_ui()
	status_label.text = "Player used Blood Sacrifice! Card replaced."
	check_game_state()

func _on_mirror_pressed() -> void:
	mirror_used = true
	mirror_button.disabled = true
	mirror_active = true
	status_label.text = "Player used Mirror Shard! Backfire damage will be reflected."

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
	
	# If the game is still going and it remains the enemy's turn (they didn't bust/cash out/pass)
	if not is_player_turn and player_current_health > 0 and enemy_current_health > 0:
		# AI continues guessing based on its card-counting logic
		enemy_ai.take_turn(current_base_value, current_combo_damage, player_current_health, enemy_cash_out_locked)

# 6. Process guess logic
func process_guess(is_higher: bool) -> void:
	var new_card: int = draw_card()
	var is_correct: bool = false
	var is_tie: bool = (new_card == current_base_value)
	
	if is_tie:
		# Ties count as a safe pass
		is_correct = true
	elif is_higher and new_card > current_base_value:
		is_correct = true
	elif not is_higher and new_card < current_base_value:
		is_correct = true
		
	if is_correct:
		if not is_tie:
			current_streak += 1
			# Exponential dynamic stake calculation: Gain = 2 ^ (streak - 1)
			current_combo_damage += int(pow(2, current_streak - 1))
		current_base_value = new_card
		combo_updated.emit(current_combo_damage)
		_update_base_card_ui()
		if not check_game_state():
			if is_player_turn:
				await get_tree().create_timer(1.2).timeout
				set_player_controls_enabled(true)
	else:
		# BUST: deduct current_combo_damage from active player's health (minimum 1 damage if combo is 0)
		var damage: int = max(1, current_combo_damage)
		if is_player_turn:
			if mirror_active:
				var reflected_damage = int(damage * 0.5)
				var self_damage = damage - reflected_damage
				player_current_health = max(0, player_current_health - self_damage)
				enemy_current_health = max(0, enemy_current_health - reflected_damage)
				mirror_active = false
				status_label.text = "Mirror Shard reflected " + str(reflected_damage) + " damage!"
			else:
				player_current_health = max(0, player_current_health - damage)
		else:
			if mirror_active:
				var reflected_damage = int(damage * 0.5)
				var self_damage = damage - reflected_damage
				enemy_current_health = max(0, enemy_current_health - self_damage)
				player_current_health = max(0, player_current_health - reflected_damage)
				mirror_active = false
				status_label.text = "Mirror Shard reflected " + str(reflected_damage) + " damage!"
			else:
				enemy_current_health = max(0, enemy_current_health - damage)
			
		current_combo_damage = 0
		current_streak = 0
		current_base_value = new_card
		
		health_changed.emit(player_current_health, enemy_current_health)
		combo_updated.emit(current_combo_damage)
		_update_base_card_ui()
		
		if not check_game_state():
			await get_tree().create_timer(1.2).timeout
			switch_turn()

# 7. Cash out logic
func cash_out() -> void:
	if current_combo_damage > 0:
		if is_player_turn:
			enemy_current_health = max(0, enemy_current_health - current_combo_damage)
		else:
			player_current_health = max(0, player_current_health - current_combo_damage)
		current_combo_damage = 0
		current_streak = 0
		
		health_changed.emit(player_current_health, enemy_current_health)
		combo_updated.emit(current_combo_damage)
		
		# Explicitly refresh UI label text
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
		enemy_cash_out_locked = false
		set_player_controls_enabled(true)
		if player_cash_out_locked:
			status_label.text = "CASH OUT LOCKED BY CHAINS OF FATE"
	else:
		player_cash_out_locked = false
		set_player_controls_enabled(false)
		if enemy_ai:
			enemy_ai.take_turn(current_base_value, current_combo_damage, player_current_health, enemy_cash_out_locked)

func set_player_controls_enabled(enabled: bool) -> void:
	higher_button.disabled = not enabled
	lower_button.disabled = not enabled
	cash_out_button.disabled = not enabled or player_cash_out_locked
	pass_button.disabled = not enabled
	
	# Trump buttons are only usable during Player's turn
	if enabled and is_player_turn:
		chains_button.disabled = chains_used
		executioner_button.disabled = executioner_used
		vision_button.disabled = vision_used
		sacrifice_button.disabled = sacrifice_used
		mirror_button.disabled = mirror_used
	else:
		chains_button.disabled = true
		executioner_button.disabled = true
		vision_button.disabled = true
		sacrifice_button.disabled = true
		mirror_button.disabled = true

# 8. Helper functions to update UI labels cleanly
func _on_health_changed(player_hp: int, enemy_hp: int) -> void:
	health_label.text = "PLAYER HP: " + str(player_hp) + " | ENTITY HP: " + str(enemy_hp)

func _on_combo_updated(current_combo: int) -> void:
	combo_label.text = "CURRENT STAKE: " + str(current_combo) + " HP"

func _update_base_card_ui() -> void:
	base_card_label.text = "CARD VALUE: " + str(current_base_value)

func _update_turn_label() -> void:
	if is_player_turn:
		turn_label.text = "YOUR TURN"
	else:
		turn_label.text = "ENEMY'S TURN..."

func _on_game_over(winner_name: String) -> void:
	base_card_label.text = "GAME OVER"
	combo_label.text = "WINNER: " + winner_name.to_upper()
	turn_label.text = winner_name.to_upper() + " WINS!"
	set_player_controls_enabled(false)
	restart_button.show()

# Returns true if the game is over
func check_game_state() -> bool:
	if player_current_health <= 0:
		game_over.emit("Entity")
		return true
	elif enemy_current_health <= 0:
		game_over.emit("Player")
		return true
	return false
