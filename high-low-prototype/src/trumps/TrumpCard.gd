extends RefCounted
class_name TrumpCard

var is_used: bool = false

func can_activate(game_manager) -> bool:
	return not is_used and game_manager != null and not game_manager.is_game_over

func execute_player(_game_manager) -> void:
	pass

func execute_enemy(_game_manager, _enemy_ai) -> void:
	pass

func can_enemy_use(_game_manager, _enemy_ai) -> bool:
	return false
