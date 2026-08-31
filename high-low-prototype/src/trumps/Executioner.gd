extends "res://src/trumps/TrumpCard.gd"

func execute_player(game_manager) -> void:
	is_used = true
	var dmg = int(game_manager.shared_pot * 0.5)
	game_manager.enemy_hp = max(0, game_manager.enemy_hp - dmg)
	game_manager.shared_pot -= dmg
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	game_manager.combo_updated.emit(game_manager.shared_pot)
	game_manager.status_label.text = "Player activated Executioner! Dealt " + str(dmg) + " damage!"
	game_manager.check_game_state()

func execute_enemy(game_manager, _enemy_ai) -> void:
	is_used = true
	var dmg = int(game_manager.shared_pot * 0.5)
	game_manager.player_hp = max(0, game_manager.player_hp - dmg)
	game_manager.shared_pot -= dmg
	game_manager.health_changed.emit(game_manager.player_hp, game_manager.enemy_hp)
	game_manager.combo_updated.emit(game_manager.shared_pot)
	game_manager.status_label.text = "Enemy activated Executioner! Dealt " + str(dmg) + " damage!"
	game_manager.check_game_state()

func can_enemy_use(game_manager, _enemy_ai) -> bool:
	if is_used:
		return false
	# Activate if shared pot >= 4
	return game_manager.shared_pot >= 4
