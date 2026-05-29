extends MarginContainer

# @onready var game_board:GameBoard = $SubViewportContainer/SubViewport/GameBoard

func _ready():
	Game.set_size(14, 8)
