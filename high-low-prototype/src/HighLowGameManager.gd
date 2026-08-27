extends Node

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
var deck: Array[int] = []

# 3. @onready variables targeting exact relative paths
@onready var base_card_label: Label = $UI_Layer/Table/BaseCardLabel
@onready var combo_label: Label = $UI_Layer/Table/ComboLabel
@onready var health_label: Label = $UI_Layer/Table/HealthLabel
@onready var higher_button: Button = $UI_Layer/ButtonsContainer/HigherButton
@onready var lower_button: Button = $UI_Layer/ButtonsContainer/LowerButton
@onready var cash_out_button: Button = $UI_Layer/ButtonsContainer/CashOutButton

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
	
	# Initialize game state
	start_new_match()
	
	# Manually call initial label text draw update so the first card is visible immediately
	_update_base_card_ui()

func start_new_match() -> void:
	player_current_health = player_max_health
	enemy_current_health = enemy_max_health
	current_combo_damage = 0
	
	# Explicitly invoke the setup updates right after setting base variables
	health_changed.emit(player_current_health, enemy_current_health)
	combo_updated.emit(current_combo_damage)
	
	rebuild_deck()
	current_base_value = draw_card()
	
	higher_button.disabled = false
	lower_button.disabled = false
	cash_out_button.disabled = false
	
	_update_base_card_ui()

func rebuild_deck() -> void:
	deck.clear()
	for i in range(1, 14):
		deck.append(i)
	deck.shuffle()

func draw_card() -> int:
	if deck.is_empty():
		rebuild_deck()
	return deck.pop_back()

# Button handlers
func _on_higher_pressed() -> void:
	process_guess(true)

func _on_lower_pressed() -> void:
	process_guess(false)

func _on_cash_out_pressed() -> void:
	cash_out()

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
			current_combo_damage += 1
		current_base_value = new_card
		combo_updated.emit(current_combo_damage)
	else:
		# BUST: deduct current_combo_damage from player_current_health (minimum 1 damage if combo is 0)
		var damage: int = max(1, current_combo_damage)
		player_current_health -= damage
		current_combo_damage = 0
		current_base_value = new_card
		
		health_changed.emit(player_current_health, enemy_current_health)
		combo_updated.emit(current_combo_damage)
		
	_update_base_card_ui()
	check_game_state()

# 7. Cash out logic
func cash_out() -> void:
	if current_combo_damage > 0:
		enemy_current_health -= current_combo_damage
		current_combo_damage = 0
		health_changed.emit(player_current_health, enemy_current_health)
		combo_updated.emit(current_combo_damage)
		check_game_state()

# 8. Helper functions to update UI labels cleanly
func _on_health_changed(player_hp: int, enemy_hp: int) -> void:
	health_label.text = "PLAYER HP: " + str(player_hp) + " | ENTITY HP: " + str(enemy_hp)

func _on_combo_updated(current_combo: int) -> void:
	combo_label.text = "CURRENT STAKE: " + str(current_combo) + " POINTS"

func _update_base_card_ui() -> void:
	base_card_label.text = "CARD VALUE: " + str(current_base_value)

func _on_game_over(winner_name: String) -> void:
	base_card_label.text = "GAME OVER"
	combo_label.text = "WINNER: " + winner_name.to_upper()
	higher_button.disabled = true
	lower_button.disabled = true
	cash_out_button.disabled = true

func check_game_state() -> void:
	if player_current_health <= 0:
		game_over.emit("Entity")
	elif enemy_current_health <= 0:
		game_over.emit("Player")
