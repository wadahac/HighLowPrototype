extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.shared_pot < 2:
		if game_manager.status_label:
			game_manager.status_label.text = "Executioner needs at least 2 in the pot!"
		return

	is_used = true
	AudioManager.play_sfx("trump_executioner")
	var dmg: int = int(game_manager.shared_pot * 0.5)
	game_manager.enemy_hp = max(0, game_manager.enemy_hp - dmg)
	game_manager.shared_pot -= dmg
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	game_manager.combo_updated.emit(game_manager.shared_pot)
	if game_manager.status_label:
		game_manager.status_label.text = "Player activated Executioner! Dealt " + str(dmg) + " damage!"
	game_manager.check_game_state()

func execute_enemy(game_manager, _enemy_ai) -> void:
	if not can_activate(game_manager):
		return
	if game_manager.shared_pot < 2:
		return

	is_used = true
	AudioManager.play_sfx("trump_executioner")
	var dmg: int = int(game_manager.shared_pot * 0.5)
	game_manager.player_hp = max(0, game_manager.player_hp - dmg)
	game_manager.shared_pot -= dmg
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	game_manager.combo_updated.emit(game_manager.shared_pot)
	if game_manager.status_label:
		game_manager.status_label.text = "Enemy activated Executioner! Dealt " + str(dmg) + " damage!"
	game_manager.check_game_state()

func can_enemy_use(game_manager, enemy_ai) -> bool:
	if not can_activate(game_manager):
		return false
	if not enemy_ai or not (self in enemy_ai.trumps_hand):
		return false
	# Activate if shared pot >= 4
	return game_manager.shared_pot >= 4
