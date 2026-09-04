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

# Tracking Current Visual State
var current_displayed_card_value: int = -1

# Trump Card State
var enemy_cash_out_and_pass_locked: bool = false
var player_cash_out_and_pass_locked: bool = false
var chained_target: String = ""
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

func get_card_texture(card_value: int) -> Texture2D:
	var path = "res://assets/cards/card_%d.png" % card_value
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var fallback_path = "res://high-low-prototype/assets/cards/card_%d.png" % card_value
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path) as Texture2D
	return null

func get_card_back_texture() -> Texture2D:
	var path = "res://assets/cards/card_back.png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var fallback_path = "res://high-low-prototype/assets/cards/card_back.png"
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path) as Texture2D
	return null

func get_trump_texture(icon_filename: String) -> Texture2D:
	var path = "res://assets/trumps/" + icon_filename
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		if tex:
			return tex
	print("TRUMP ICON ERROR: Failed to load icon at ", path)
	return null

func apply_button_theme(btn: Button) -> void:
	var bg_tex = get_trump_texture("card_back.png")
	var frame_tex = get_trump_texture("ui_frame.png")
	
	if bg_tex != null:
		var sb_normal = StyleBoxTexture.new()
		sb_normal.texture = bg_tex
		btn.add_theme_stylebox_override("normal", sb_normal)
		btn.add_theme_stylebox_override("pressed", sb_normal)
		
	if frame_tex != null:
		var sb_hover = StyleBoxTexture.new()
		sb_hover.texture = frame_tex
		btn.add_theme_stylebox_override("hover", sb_hover)
		
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func animate_card_flip(new_card_value: int) -> void:
	if not has_node("UI_Layer/Table/CardDisplay"):
		return
	var card_display = get_node("UI_Layer/Table/CardDisplay")
	if not card_display:
		return
		
	if new_card_value == current_displayed_card_value:
		card_display.texture = get_card_texture(new_card_value)
		return
		
	current_displayed_card_value = new_card_value
	var tween = create_tween()
	tween.tween_property(card_display, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		card_display.texture = get_card_texture(new_card_value)
	)
	tween.tween_property(card_display, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func reset_game() -> void:
	current_displayed_card_value = -1
	if has_node("UI_Layer/Table/CardDisplay"):
		var card_display = get_node("UI_Layer/Table/CardDisplay")
		if card_display:
			card_display.texture = get_card_back_texture()
			card_display.scale.x = 1.0

	player_hp = player_max_health
	enemy_hp = enemy_max_health
	shared_pot = 0
	current_streak = 0
	is_player_turn = true
	enemy_cash_out_and_pass_locked = false
	player_cash_out_and_pass_locked = false
	chained_target = ""
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
	if is_player_turn:
		set_player_controls_enabled(false)
		cash_out()

func _on_pass_pressed() -> void:
	if (is_player_turn and player_cash_out_and_pass_locked) or (not is_player_turn and enemy_cash_out_and_pass_locked):
		print("ACTION BLOCKED: Pass called while locked by Chains of Fate!")
		return

	if is_player_turn:
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
		
	# Clean up previously generated dynamic buttons inside TrumpContainer
	for child in container.get_children():
		if child.is_in_group("stolen_trump_button"):
			container.remove_child(child)
			child.queue_free()
		
	# Adjust Container Separation to accommodate larger buttons
	container.add_theme_constant_override("separation", 10)
		
	# Check which types of trumps are currently active (not used) in the player's hand
	var has_chains = false
	var has_executioner = false
	var has_vision = false
	var has_sacrifice = false
	var has_mirror = false
	
	for trump in trumps_hand:
		if not trump.is_used:
			var file_name = trump.get_script().get_path().get_file().get_basename().to_lower()
			if "chainsoffate" in file_name or "chains" in file_name:
				has_chains = true
			elif "executioner" in file_name:
				has_executioner = true
			elif "propheticvision" in file_name or "vision" in file_name:
				has_vision = true
			elif "bloodsacrifice" in file_name or "sacrifice" in file_name:
				has_sacrifice = true
			elif "mirrorshard" in file_name or "mirror" in file_name:
				has_mirror = true

	# Update button visibilities and disabled states dynamically
	_update_button_state(chains_button, has_chains, chains_trump)
	_update_button_state(executioner_button, has_executioner, executioner_trump)
	_update_button_state(vision_button, has_vision, vision_trump)
	_update_button_state(sacrifice_button, has_sacrifice, sacrifice_trump)
	_update_button_state(mirror_button, has_mirror, mirror_trump)
	
	if steal_button:
		steal_button.custom_minimum_size = Vector2(56, 56)
		steal_button.visible = not steal_trump.is_used
		steal_button.disabled = not is_player_turn
		steal_button.flat = false
		apply_button_theme(steal_button)
		if not steal_trump.is_used:
			var tex = get_trump_texture("SoulThievery.png")
			if tex != null:
				steal_button.icon = tex
				steal_button.expand_icon = true
				steal_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				steal_button.text = ""
			else:
				steal_button.icon = null
				steal_button.text = "Steal"

	# Identify and Instantiate Stolen/Extra Trumps
	var base_instances = [chains_trump, executioner_trump, vision_trump, sacrifice_trump, mirror_trump]
	for trump in trumps_hand:
		if trump not in base_instances and not trump.is_used:
			var new_btn = Button.new()
			new_btn.add_to_group("stolen_trump_button")
			new_btn.custom_minimum_size = Vector2(56, 56)
			new_btn.disabled = not is_player_turn
			apply_button_theme(new_btn)
			
			var file_name_lower = trump.get_script().get_path().get_file().get_basename().to_lower()
			var filename = ""
			if "chains" in file_name_lower:
				filename = "chains.png"
			elif "executioner" in file_name_lower:
				filename = "executioner.png"
			elif "vision" in file_name_lower or "prophetic" in file_name_lower:
				filename = "vision.png"
			elif "sacrifice" in file_name_lower or "blood" in file_name_lower:
				filename = "sacrifice.png"
			elif "mirror" in file_name_lower:
				filename = "mirror.png"
				
			var tex = get_trump_texture(filename) if filename != "" else null
			if tex != null:
				new_btn.icon = tex
				new_btn.expand_icon = true
				new_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				new_btn.text = ""
			else:
				new_btn.icon = null
				new_btn.text = trump.card_name if "card_name" in trump else "Stolen"
				
			new_btn.pressed.connect(func():
				trump.execute_player(self)
				refresh_trump_ui()
				set_player_controls_enabled(is_player_turn)
			)
			container.add_child(new_btn)

	# Re-enforce active turn lock at the very end of UI refresh
	if is_player_turn and player_cash_out_and_pass_locked:
		pass_button.disabled = true
		cash_out_button.disabled = true
		if status_label:
			status_label.text = "TRAPPED BY CHAINS OF FATE: YOU MUST GUESS!"
