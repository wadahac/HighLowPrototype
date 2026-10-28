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
var deck: Array[int] = []
var is_player_turn: bool = true

# Match lifecycle state. Async actions capture match_id and abort if it changes.
var match_id: int = 0
var is_game_over: bool = false

# Tracking Current Visual State
var current_displayed_card_value: int = -1
var card_flip_tween: Tween = null

# Feedback animation and delta tracking
var status_pulse_tween: Tween = null
var health_pulse_tween: Tween = null
var combo_pulse_tween: Tween = null
var turn_pulse_tween: Tween = null
var last_player_hp: int = 10
var last_enemy_hp: int = 10
var last_shared_pot: int = 0
var thinking_elapsed: float = 0.0

# Trump Card State
var enemy_cash_out_and_pass_locked: bool = false
var player_cash_out_and_pass_locked: bool = false
var chained_target: String = ""
var mirror_active: bool = false
var mirror_owner: String = ""
var known_future_3rd_card: int = -1
var prophetic_vision_turn_countdown: int = -1
var vision_owner: String = ""

const CARD_NAMES: Array[String] = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

const STATUS_COLORS: Dictionary = {
	"info": Color(0.96, 0.93, 0.84),
	"good": Color(0.58, 0.90, 0.57),
	"bad": Color(1.0, 0.47, 0.42),
	"warn": Color(1.0, 0.80, 0.36),
	"chain": Color(0.85, 0.65, 1.0),
	"muted": Color(0.72, 0.74, 0.78)
}

const CONTROL_DIM_COLOR: Color = Color(0.62, 0.62, 0.62, 0.78)

const TRUMP_HELP: Dictionary = {
	"Chains of Fate": "Target cannot cash out or pass next turn and must guess. Correct guesses double the pot; wrong guesses double the damage.",
	"Executioner": "Deal half the current pot as damage. The pot shrinks by the damage dealt.",
	"Prophetic Vision": "Reveal the third card in the deck. Lasts until it is drawn or the deck reshuffles.",
	"Blood Sacrifice": "Lose 2 HP and replace the active card with a fresh draw.",
	"Mirror Shard": "Reflects half of the next backfire damage, rounded down. Expires when the turn changes.",
	"Soul Thievery": "Steal a random enemy trump and refresh it for your use."
}

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
@onready var steal_button: Button = $UI_Layer/TrumpContainer/StealButton

# Info Labels
@onready var vision_label: Label = $"UI_Layer/InfoPanel/VisionLabel"
@onready var status_label: Label = $"UI_Layer/InfoPanel/StatusLabel"

# Persistent effect and feedback UI
@onready var effect_bar: HBoxContainer = $UI_Layer/EffectBar
@onready var chains_badge: PanelContainer = $UI_Layer/EffectBar/ChainsBadge
@onready var chains_badge_label: Label = $UI_Layer/EffectBar/ChainsBadge/ChainsLabel
@onready var mirror_badge: PanelContainer = $UI_Layer/EffectBar/MirrorBadge
@onready var mirror_badge_label: Label = $UI_Layer/EffectBar/MirrorBadge/MirrorLabel
@onready var vision_badge: PanelContainer = $UI_Layer/EffectBar/VisionBadge
@onready var vision_badge_label: Label = $UI_Layer/EffectBar/VisionBadge/VisionBadgeLabel
@onready var thinking_badge: PanelContainer = $UI_Layer/EffectBar/ThinkingBadge
@onready var thinking_label: Label = $UI_Layer/EffectBar/ThinkingBadge/ThinkingLabel
@onready var floating_text_layer: Control = $UI_Layer/FloatingTextLayer

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
	
	# Connect Steal button
	steal_button.pressed.connect(_on_steal_button_pressed)
	
	if enemy_ai:
		enemy_ai.decision_made.connect(_on_enemy_decision_made)
	
	_setup_control_tooltips()
	restart_button.hide()
	reset_game()
	print("GAME INITIALIZED SUCCESSFULLY")

func _process(delta: float) -> void:
	if not thinking_badge or not thinking_badge.visible:
		return
	thinking_elapsed += delta
	_update_thinking_text()

func _setup_control_tooltips() -> void:
	higher_button.tooltip_text = "Guess the next card is higher. Correct (ties count): the pot grows. Wrong: take pot damage."
	lower_button.tooltip_text = "Guess the next card is lower. Correct (ties count): the pot grows. Wrong: take pot damage."
	cash_out_button.tooltip_text = "Deal the entire shared pot as damage, then switch turns."
	pass_button.tooltip_text = "Keep the pot and active card, then switch turns."
	restart_button.tooltip_text = "Start a fresh match."

func get_trump_tooltip(trump_instance) -> String:
	var display_name = get_trump_display_name(trump_instance)
	var description = TRUMP_HELP.get(display_name, "")
	if description == "":
		return display_name
	return display_name + " - " + description

func get_card_texture(card_value: int) -> Texture2D:
	var path = "res://assets/cards/card_%d.png" % card_value
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_card_back_texture() -> Texture2D:
	var path = "res://assets/cards/card_back.png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
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

	if card_flip_tween and card_flip_tween.is_valid():
		card_flip_tween.kill()
		card_display.scale.x = 1.0

	if new_card_value == current_displayed_card_value:
		card_display.texture = get_card_texture(new_card_value)
		return

	current_displayed_card_value = new_card_value
	if card_display.size.x > 0.0:
		card_display.pivot_offset = card_display.size * 0.5
	var tween = create_tween()
	card_flip_tween = tween
	tween.tween_property(card_display, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		AudioManager.play_sfx("card_place")
		card_display.texture = get_card_texture(new_card_value)
	)
	tween.tween_property(card_display, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func reset_game() -> void:
	match_id += 1
	is_game_over = false
	current_displayed_card_value = -1
	if card_flip_tween and card_flip_tween.is_valid():
		card_flip_tween.kill()
	if has_node("UI_Layer/Table/CardDisplay"):
		var card_display = get_node("UI_Layer/Table/CardDisplay")
		if card_display:
			card_display.texture = get_card_back_texture()
			card_display.scale.x = 1.0

	_reset_feedback_animations()
	thinking_elapsed = 0.0
	player_hp = player_max_health
	enemy_hp = enemy_max_health
	shared_pot = 0
	last_player_hp = player_hp
	last_enemy_hp = enemy_hp
	last_shared_pot = shared_pot
	active_card = 0
	is_player_turn = true
	enemy_cash_out_and_pass_locked = false
	player_cash_out_and_pass_locked = false
	chained_target = ""
	mirror_active = false
	mirror_owner = ""
	known_future_3rd_card = -1
	prophetic_vision_turn_countdown = -1
	vision_owner = ""
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
	set_status("", "info")
	
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
	set_status("Your turn. Guess Higher or Lower, or play a Trump.", "info")
	_refresh_effect_badges()

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
	vision_owner = ""
	if vision_label:
		vision_label.text = ""
	print("[DECK] Reshuffled 13-card deck.")
	set_status("DECK RESHUFFLED! (Strategic 13-card pool refreshed)", "warn")

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
		if prophetic_vision_turn_countdown == 0:
			known_future_3rd_card = -1
			vision_owner = ""

	# The next draw reshuffles when fewer than 3 cards remain. A reshuffle
	# destroys the old deck order, so any remaining vision prediction is stale.
	if deck.size() < 3:
		known_future_3rd_card = -1
		prophetic_vision_turn_countdown = -1
		vision_owner = ""
	_update_vision_label()
		
	if enemy_ai:
		enemy_ai.record_card_drawn(card)
	return card

func get_card_name(card_value: int) -> String:
	if card_value >= 1 and card_value <= 13:
		return CARD_NAMES[card_value]
	return str(card_value)

func _update_vision_label() -> void:
	if not vision_label:
		_refresh_effect_badges()
		return
	if vision_owner != "player" or known_future_3rd_card == -1 or prophetic_vision_turn_countdown <= 0:
		vision_label.text = ""
	else:
		var card_name = get_card_name(known_future_3rd_card)
		if prophetic_vision_turn_countdown == 1:
			vision_label.text = "Vision: next card is " + card_name
		else:
			vision_label.text = "Vision: " + card_name + " in " + str(prophetic_vision_turn_countdown) + " draws"
	_refresh_effect_badges()

func refresh_vision_label() -> void:
	_update_vision_label()

func refresh_effect_badges() -> void:
	_refresh_effect_badges()

func set_status(message: String, tone: String = "info") -> void:
	if not status_label:
		return
	var changed: bool = status_label.text != message
	status_label.text = message
	var color: Color = STATUS_COLORS.get(tone, STATUS_COLORS["info"])
	status_label.add_theme_color_override("font_color", color)
	if changed:
		if status_pulse_tween and status_pulse_tween.is_valid():
			status_pulse_tween.kill()
		status_label.modulate = Color(1.2, 1.2, 1.2, 1.0)
		status_pulse_tween = create_tween()
		status_pulse_tween.tween_property(status_label, "modulate", Color.WHITE, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_effect_badge(badge: PanelContainer, label: Label, text: String) -> bool:
	if not badge:
		return false
	badge.visible = text != ""
	if label:
		label.text = text
	return badge.visible

func _update_thinking_text() -> void:
	if not thinking_label:
		return
	var dots: int = int(thinking_elapsed * 2.5) % 4
	thinking_label.text = "ENEMY THINKING" + ["", ".", "..", "..."][dots]

func _refresh_effect_badges() -> void:
	if not effect_bar:
		return

	var chains_text := ""
	var mirror_text := ""
	var vision_text := ""

	if not is_game_over:
		if player_cash_out_and_pass_locked and enemy_cash_out_and_pass_locked:
			chains_text = "CHAINS: BOTH"
		elif player_cash_out_and_pass_locked:
			chains_text = "CHAINS: YOU"
		elif enemy_cash_out_and_pass_locked:
			chains_text = "CHAINS: ENEMY"

		if mirror_active:
			mirror_text = "MIRROR: YOU" if mirror_owner == "player" else "MIRROR: ENEMY"

		if vision_owner != "" and prophetic_vision_turn_countdown > 0:
			if vision_owner == "player":
				if prophetic_vision_turn_countdown == 1:
					vision_text = "VISION: NEXT CARD"
				else:
					vision_text = "VISION: " + str(prophetic_vision_turn_countdown) + " DRAWS"
			else:
				vision_text = "VISION: ENEMY"

	var chains_visible: bool = _set_effect_badge(chains_badge, chains_badge_label, chains_text)
	var mirror_visible: bool = _set_effect_badge(mirror_badge, mirror_badge_label, mirror_text)
	var vision_visible: bool = _set_effect_badge(vision_badge, vision_badge_label, vision_text)

	var thinking_visible: bool = not is_game_over and not is_player_turn
	if thinking_badge:
		if thinking_visible and not thinking_badge.visible:
			thinking_elapsed = 0.0
		thinking_badge.visible = thinking_visible
		if thinking_visible:
			_update_thinking_text()

	effect_bar.visible = chains_visible or mirror_visible or vision_visible or thinking_visible

func _set_control_state(button: Button, enabled: bool) -> void:
	if not button:
		return
	button.disabled = not enabled
	button.modulate = Color.WHITE if enabled else CONTROL_DIM_COLOR
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW

func _pulse_label(control: Control, existing: Tween) -> Tween:
	if existing and existing.is_valid():
		existing.kill()
	control.scale = Vector2.ONE
	if control.size.x > 0.0 and control.size.y > 0.0:
		control.pivot_offset = control.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(control, "scale", Vector2(1.09, 1.09), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween

func _clear_floating_texts() -> void:
	if not floating_text_layer:
		return
	for child in floating_text_layer.get_children():
		child.queue_free()

func _reset_feedback_animations() -> void:
	for tween in [status_pulse_tween, health_pulse_tween, combo_pulse_tween, turn_pulse_tween]:
		if tween and tween.is_valid():
			tween.kill()
	status_pulse_tween = null
	health_pulse_tween = null
	combo_pulse_tween = null
	turn_pulse_tween = null
	if status_label:
		status_label.modulate = Color.WHITE
	if health_label:
		health_label.scale = Vector2.ONE
	if combo_label:
		combo_label.scale = Vector2.ONE
	if turn_label:
		turn_label.scale = Vector2.ONE
	_clear_floating_texts()

func _card_feedback_center() -> Vector2:
	var global_center: Vector2
	if has_node("UI_Layer/Table/CardDisplay"):
		global_center = get_node("UI_Layer/Table/CardDisplay").get_global_rect().get_center()
	else:
		global_center = get_viewport_rect().size * 0.5
	if floating_text_layer:
		return floating_text_layer.get_global_transform().affine_inverse() * global_center
	return global_center

func _health_feedback_center(is_player: bool) -> Vector2:
	return _card_feedback_center() + Vector2(-260.0 if is_player else 260.0, 0.0)

func _spawn_floating_text(message: String, center: Vector2, color: Color) -> void:
	if not floating_text_layer:
		return
	var label := Label.new()
	label.text = message
	label.size = Vector2(180.0, 32.0)
	label.position = center - Vector2(90.0, 16.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_text_layer.add_child(label)

	var tween: Tween = create_tween()
	tween.bind_node(label)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 36.0, 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.25)
	tween.finished.connect(label.queue_free)

func replace_active_card() -> int:
	active_card = draw_card()
	_update_base_card_ui()
	return active_card

# Button handlers
func _on_higher_pressed() -> void:
	if is_player_turn and not is_game_over:
		AudioManager.play_sfx("click")
		set_player_controls_enabled(false)
		process_guess(true)

func _on_lower_pressed() -> void:
	if is_player_turn and not is_game_over:
		AudioManager.play_sfx("click")
		set_player_controls_enabled(false)
		process_guess(false)

func _on_cash_out_pressed() -> void:
	if is_player_turn and not is_game_over and shared_pot > 0 and not player_cash_out_and_pass_locked:
		set_player_controls_enabled(false)
		cash_out()

func _on_pass_pressed() -> void:
	if is_game_over:
		return
	if (is_player_turn and player_cash_out_and_pass_locked) or (not is_player_turn and enemy_cash_out_and_pass_locked):
		print("ACTION BLOCKED: Pass called while locked by Chains of Fate!")
		return

	if is_player_turn:
		AudioManager.play_sfx("click")
		set_player_controls_enabled(false)
		set_status("Player passed the turn. Pot remains " + str(shared_pot) + ".", "info")
		switch_turn()

# Reuse Existing UI Buttons (Do NOT Create New Nodes)
func update_trump_ui() -> void:
	refresh_trump_ui()

func _get_trump_icon_filename(trump_instance) -> String:
	var file_name_lower = trump_instance.get_script().get_path().get_file().get_basename().to_lower()
	if "chains" in file_name_lower:
		return "chains.png"
	elif "executioner" in file_name_lower:
		return "executioner.png"
	elif "vision" in file_name_lower or "prophetic" in file_name_lower:
		return "vision.png"
	elif "sacrifice" in file_name_lower or "blood" in file_name_lower:
		return "sacrifice.png"
	elif "mirror" in file_name_lower:
		return "mirror.png"
	elif "thievery" in file_name_lower or "soul" in file_name_lower:
		return "SoulThievery.png"
	return ""

func get_trump_display_name(trump_instance) -> String:
	var base_name = trump_instance.get_script().get_path().get_file().get_basename()
	var display_names: Dictionary = {
		"ChainsOfFate": "Chains of Fate",
		"Executioner": "Executioner",
		"PropheticVision": "Prophetic Vision",
		"BloodSacrifice": "Blood Sacrifice",
		"MirrorShard": "Mirror Shard",
		"SoulThievery": "Soul Thievery"
	}
	return display_names.get(base_name, base_name)

func _apply_trump_icon(btn: Button, trump_instance, fallback_name: String) -> void:
	var filename = _get_trump_icon_filename(trump_instance)
	var tex = get_trump_texture(filename) if filename != "" else null
	if tex != null:
		btn.icon = tex
		btn.expand_icon = true
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.text = ""
	else:
		btn.icon = null
		btn.text = fallback_name

func _setup_base_button(btn: Button, trump_instance) -> void:
	if not btn:
		return
	
	# Clear old connections
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn.callable)
		
	var is_available = (trump_instance in trumps_hand) and (not trump_instance.is_used)
	btn.visible = is_available
	btn.tooltip_text = get_trump_tooltip(trump_instance)
	_set_control_state(btn, is_player_turn and not is_game_over)
	btn.custom_minimum_size = Vector2(56, 56)
	btn.flat = false
	apply_button_theme(btn)
	
	if is_available:
		_apply_trump_icon(btn, trump_instance, get_trump_display_name(trump_instance))
		btn.pressed.connect(func():
			if is_game_over or not is_player_turn:
				return
			trump_instance.execute_player(self)
			refresh_trump_ui()
			set_player_controls_enabled(is_player_turn)
		)

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

	# Setup the 5 base buttons representing ONLY their original starting card instances
	_setup_base_button(chains_button, chains_trump)
	_setup_base_button(executioner_button, executioner_trump)
	_setup_base_button(vision_button, vision_trump)
	_setup_base_button(sacrifice_button, sacrifice_trump)
	_setup_base_button(mirror_button, mirror_trump)
	
	if steal_button:
		steal_button.custom_minimum_size = Vector2(56, 56)
		steal_button.visible = not steal_trump.is_used
		steal_button.tooltip_text = get_trump_tooltip(steal_trump)
		_set_control_state(steal_button, not steal_trump.is_used and is_player_turn and not is_game_over)
		steal_button.flat = false
		apply_button_theme(steal_button)
		if not steal_trump.is_used:
			_apply_trump_icon(steal_button, steal_trump, "Steal")

	# Identify and Instantiate Stolen/Extra Trumps
	var base_instances = [chains_trump, executioner_trump, vision_trump, sacrifice_trump, mirror_trump]
	for trump in trumps_hand:
		if trump not in base_instances and not trump.is_used:
			var new_btn = Button.new()
			new_btn.add_to_group("stolen_trump_button")
			new_btn.custom_minimum_size = Vector2(56, 56)
			new_btn.tooltip_text = get_trump_tooltip(trump)
			_set_control_state(new_btn, is_player_turn and not is_game_over)
			apply_button_theme(new_btn)
			_apply_trump_icon(new_btn, trump, get_trump_display_name(trump))
				
			new_btn.pressed.connect(func():
				if is_game_over or not is_player_turn:
					return
				trump.execute_player(self)
				refresh_trump_ui()
				set_player_controls_enabled(is_player_turn)
			)
			container.add_child(new_btn)

	# Re-enforce active turn lock at the very end of UI refresh. Don't clobber
	# a trump/steal result message that was just shown; switch_turn() supplies
	# the trapped reminder at the start of a locked turn.
	if is_player_turn and player_cash_out_and_pass_locked and not is_game_over:
		_set_control_state(pass_button, false)
		_set_control_state(cash_out_button, false)
		if status_label and (status_label.text.is_empty() or status_label.text.begins_with("Your turn")):
			set_status("TRAPPED BY CHAINS OF FATE: YOU MUST GUESS!", "chain")

	_refresh_effect_badges()

func _set_dynamic_trump_buttons_disabled(disabled: bool) -> void:
	var container = $UI_Layer/TrumpContainer
	if not container:
		return
	for child in container.get_children():
		if child.is_in_group("stolen_trump_button"):
			_set_control_state(child, not disabled)

func _on_steal_button_pressed() -> void:
	if is_game_over or not is_player_turn or steal_trump.is_used:
		return
	var stolen_trump = steal_trump.apply_effect(self, enemy_ai, self)
	if stolen_trump:
		var stolen_name = get_trump_display_name(stolen_trump)
		print("STOLE TRUMP: Stole ", stolen_name)
		set_status("Player stole " + stolen_name + "!", "good")
	else:
		set_status("Player tried to steal, but enemy has no Trumps!", "warn")
	refresh_trump_ui()
	set_player_controls_enabled(is_player_turn)
	_update_base_card_ui()

func trigger_juice_effect(effect_name: String) -> void:
	print("Juice effect triggered: ", effect_name)
	set_status("Juice effect: " + effect_name.to_upper(), "info")

# AI Decision Handler
func _on_enemy_decision_made(choice: String) -> void:
	if is_game_over or is_player_turn:
		return
	
	if choice == "cash_out":
		cash_out()
	elif choice == "pass":
		set_status("Enemy passed the turn. Pot remains " + str(shared_pot) + ".", "info")
		switch_turn()
	elif choice == "higher" or choice == "lower":
		process_guess(choice == "higher")

# Chains of Fate only affects the player whose turn it currently is.
# The opponent's pending trap must survive until their own turn starts.
func _consume_chain_for_current_player() -> void:
	if is_player_turn:
		player_cash_out_and_pass_locked = false
		if chained_target == "player":
			chained_target = ""
	else:
		enemy_cash_out_and_pass_locked = false
		if chained_target == "enemy":
			chained_target = ""
	_refresh_effect_badges()

# Process guess logic
func process_guess(is_higher: bool) -> void:
	if is_game_over:
		return
	var started_match: int = match_id
	var acting_name: String = "Player" if is_player_turn else "Enemy"
	var active_is_chained: bool = player_cash_out_and_pass_locked if is_player_turn else enemy_cash_out_and_pass_locked
	var pot_snapshot: int = shared_pot
	print("DEBUG - Guess Start: is_player_turn=", is_player_turn, " active_is_chained=", active_is_chained, " pot=", pot_snapshot)

	var new_card: int = draw_card()
	var is_reshuffled: bool = was_reshuffled_on_last_draw
	var is_tie: bool = (new_card == active_card)
	var is_correct: bool = is_tie \
		or (is_higher and new_card > active_card) \
		or (not is_higher and new_card < active_card)
	var text_prefix: String = "DECK RESHUFFLED! " if is_reshuffled else ""
	
	if is_correct:
		if not is_tie:
			shared_pot += 1
			if active_is_chained:
				shared_pot *= 2
				print("DEBUG: Chains of Fate DOUBLE POT applied! New pot: ", shared_pot)
		active_card = new_card
		combo_updated.emit(shared_pot)
		_update_base_card_ui()

		if status_label:
			if is_tie:
				set_status(text_prefix + acting_name + " tied. Pot stays at " + str(shared_pot) + ".", "info")
			elif active_is_chained:
				set_status(text_prefix + acting_name + " survived Chains of Fate! Pot doubled to " + str(shared_pot) + "!", "chain")
			else:
				set_status(text_prefix + acting_name + " guessed correctly! Pot is now " + str(shared_pot) + ".", "good")

		# Consume the current guesser's trap BEFORE controls are re-enabled.
		# This is what keeps Cash Out/Pass usable after surviving a forced guess.
		_consume_chain_for_current_player()

		await get_tree().create_timer(1.2).timeout
		if started_match != match_id or is_game_over:
			return
		if is_player_turn:
			set_player_controls_enabled(true)
		elif enemy_ai:
			enemy_ai.take_turn()
	else:
		AudioManager.play_sfx("take_damage")
		
		var total_damage: int = max(1, pot_snapshot * 2) if active_is_chained else max(1, pot_snapshot)
		var current_owner: String = "player" if is_player_turn else "enemy"
		var mirror_applied: bool = mirror_active and mirror_owner == current_owner

		if mirror_applied:
			var reflected_damage: int = int(total_damage * 0.5)
			var self_damage: int = total_damage - reflected_damage
			if is_player_turn:
				player_hp = max(0, player_hp - self_damage)
				enemy_hp = max(0, enemy_hp - reflected_damage)
			else:
				enemy_hp = max(0, enemy_hp - self_damage)
				player_hp = max(0, player_hp - reflected_damage)
			if status_label:
				set_status(text_prefix + "Mirror Shard split " + str(total_damage) + " damage! " \
					+ acting_name + " took " + str(self_damage) + ", opponent took " + str(reflected_damage) + ".", "bad")
		else:
			if is_player_turn:
				player_hp = max(0, player_hp - total_damage)
			else:
				enemy_hp = max(0, enemy_hp - total_damage)
			if status_label:
				var chain_text: String = " (Chains of Fate backfire)" if active_is_chained else ""
				set_status(text_prefix + acting_name + " guessed incorrectly and took " + str(total_damage) + " damage" + chain_text + ".", "bad")

		mirror_active = false
		mirror_owner = ""
		shared_pot = 0
		active_card = new_card
		_consume_chain_for_current_player()
		
		health_changed.emit(player_hp, enemy_hp)
		combo_updated.emit(shared_pot)
		_update_base_card_ui()
		
		if check_game_over():
			return
		await get_tree().create_timer(1.2).timeout
		if started_match != match_id or is_game_over:
			return
		switch_turn()

# Cash out logic
func cash_out() -> void:
	if is_game_over:
		return
	if (is_player_turn and player_cash_out_and_pass_locked) or (not is_player_turn and enemy_cash_out_and_pass_locked):
		print("ACTION BLOCKED: Cash Out called while locked by Chains of Fate!")
		return
	if shared_pot <= 0:
		return

	var started_match: int = match_id
	var acting_name: String = "Player" if is_player_turn else "Enemy"
	var damage: int = shared_pot
	AudioManager.play_sfx("cash_out")
	AudioManager.play_sfx("take_damage")
	if is_player_turn:
		enemy_hp = max(0, enemy_hp - damage)
	else:
		player_hp = max(0, player_hp - damage)
	shared_pot = 0

	set_status(acting_name + " cashed out for " + str(damage) + " damage!", "good" if is_player_turn else "bad")

	health_changed.emit(player_hp, enemy_hp)
	combo_updated.emit(shared_pot)
	_update_base_card_ui()

	if check_game_over():
		return
	await get_tree().create_timer(1.2).timeout
	if started_match != match_id or is_game_over:
		return
	switch_turn()

func switch_turn() -> void:
	if is_game_over:
		return
	AudioManager.play_sfx("switch_turn")
	is_player_turn = not is_player_turn

	# A Mirror Shard only protects the turn it was activated on.
	mirror_active = false
	mirror_owner = ""

	_update_turn_label()
	refresh_trump_ui()
	
	if is_player_turn:
		set_player_controls_enabled(true)
		if player_cash_out_and_pass_locked:
			set_status("TRAPPED BY CHAINS OF FATE: YOU MUST GUESS!", "chain")
	else:
		set_player_controls_enabled(false)
		if enemy_ai:
			enemy_ai.take_turn()
	_refresh_effect_badges()

func set_player_controls_enabled(enabled: bool) -> void:
	if is_game_over:
		enabled = false
	var can_use: bool = enabled and is_player_turn
	_set_control_state(higher_button, can_use)
	_set_control_state(lower_button, can_use)
	
	if can_use:
		var is_player_chained: bool = player_cash_out_and_pass_locked
		_set_control_state(cash_out_button, not is_player_chained and shared_pot > 0)
		_set_control_state(pass_button, not is_player_chained)
		
		# Update Trump buttons state
		refresh_trump_ui()
	else:
		_set_control_state(cash_out_button, false)
		_set_control_state(pass_button, false)
		_set_control_state(chains_button, false)
		_set_control_state(executioner_button, false)
		_set_control_state(vision_button, false)
		_set_control_state(sacrifice_button, false)
		_set_control_state(mirror_button, false)
		_set_control_state(steal_button, false)
		_set_dynamic_trump_buttons_disabled(true)
	_refresh_effect_badges()

func check_game_over() -> bool:
	if is_game_over:
		return true

	var winner: String = ""
	if player_hp <= 0 and enemy_hp <= 0:
		winner = "Draw"
		AudioManager.play_sfx("game_over")
		set_status("DOUBLE KO! IT'S A DRAW!", "warn")
	elif enemy_hp <= 0:
		winner = "Player"
		set_status("YOU SURVIVED! YOU WIN!", "good")
	elif player_hp <= 0:
		winner = "Enemy"
		AudioManager.play_sfx("game_over")
		set_status("YOU DIED! GAME OVER", "bad")
	else:
		return false

	is_game_over = true
	_disable_all_controls()
	restart_button.show()
	restart_button.disabled = false
	_refresh_effect_badges()
	game_over.emit(winner)
	return true

func check_game_state() -> bool:
	return check_game_over()

func _disable_all_controls() -> void:
	set_player_controls_enabled(false)

func _update_base_card_ui() -> void:
	animate_card_flip(active_card)

func _update_turn_label() -> void:
	if turn_label:
		if is_player_turn:
			turn_label.text = "YOUR TURN"
			turn_label.add_theme_color_override("font_color", Color(0.68, 0.94, 0.65))
		else:
			turn_label.text = "ENEMY TURN"
			turn_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
		turn_pulse_tween = _pulse_label(turn_label, turn_pulse_tween)

func _on_health_changed(p_hp: int, e_hp: int) -> void:
	if health_label:
		health_label.text = "Player HP: " + str(p_hp) + " | Enemy HP: " + str(e_hp)

	var changed: bool = p_hp != last_player_hp or e_hp != last_enemy_hp
	if p_hp < last_player_hp:
		_spawn_floating_text("YOU -" + str(last_player_hp - p_hp), _health_feedback_center(true), STATUS_COLORS["bad"])
	elif p_hp > last_player_hp:
		_spawn_floating_text("YOU +" + str(p_hp - last_player_hp), _health_feedback_center(true), STATUS_COLORS["good"])
	if e_hp < last_enemy_hp:
		_spawn_floating_text("ENEMY -" + str(last_enemy_hp - e_hp), _health_feedback_center(false), STATUS_COLORS["bad"])
	elif e_hp > last_enemy_hp:
		_spawn_floating_text("ENEMY +" + str(e_hp - last_enemy_hp), _health_feedback_center(false), STATUS_COLORS["good"])

	if changed and health_label:
		health_pulse_tween = _pulse_label(health_label, health_pulse_tween)
	last_player_hp = p_hp
	last_enemy_hp = e_hp

func _on_combo_updated(c_combo: int) -> void:
	if combo_label:
		combo_label.text = "Shared Pot: " + str(c_combo)

	var difference: int = c_combo - last_shared_pot
	if difference > 0:
		_spawn_floating_text("+" + str(difference) + " POT", _card_feedback_center() + Vector2(0.0, -210.0), STATUS_COLORS["good"])
	elif difference < 0:
		_spawn_floating_text(str(difference) + " POT", _card_feedback_center() + Vector2(0.0, -210.0), STATUS_COLORS["warn"])

	if difference != 0 and combo_label:
		combo_pulse_tween = _pulse_label(combo_label, combo_pulse_tween)
	last_shared_pot = c_combo

func _on_game_over(winner: String) -> void:
	is_game_over = true
	_disable_all_controls()
	restart_button.show()
	restart_button.disabled = false
	_refresh_effect_badges()
