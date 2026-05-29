extends TileMapLayer

class_name GameBoard

const TILE_SOURCE_ID:int = 0
const TILE_ATLAS_COORDS:Vector2i = Vector2i(0, 0)

@onready var game_piece_scene:PackedScene = preload("res://scenes/game_piece.tscn")

@onready var camera:Camera2D = $Camera2D

var game_pieces:Array = []
var scoring_game_pieces:Array = []

var mouse_was_pressed:bool = false
var mouse_down_map_position:Vector2i = Vector2i.MIN
var mouse_up_map_position:Vector2i = Vector2i.MIN
var selected_piece_map_position:Vector2i = Vector2i.MIN:
	get:
		return selected_piece_map_position
	set(value):
		if selected_piece_map_position == value:
			return
		var board_rect:Rect2i = Rect2i(0, 0, Game.board_width, Game.board_height)
		if board_rect.has_point(selected_piece_map_position):
			game_pieces[Game.map_to_index(selected_piece_map_position)].stop_glow()
		selected_piece_map_position = value
		if board_rect.has_point(selected_piece_map_position):
			game_pieces[Game.map_to_index(selected_piece_map_position)].start_glow()

# ================================================================

func _ready() -> void:
	Game.board_resized.connect(_on_board_resized)
	Game.letter_added.connect(_spawn_game_piece)
	Game.letter_swapped.connect(_swap_letter)
	Game.letter_scored.connect(_score_letter)
	Game.letter_erased.connect(_erase_letter)

# ================================================================
# Game Board and Piece Management

func _on_board_resized(_old_width:int = 0, _old_height:int = 0):
	_resize_board()
	_recenter_camera()

func _resize_board() -> void:
	_clear_game_pieces()
	clear()
	for x:int in Game.board_width:
		for y:int in Game.board_height:
			set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_ATLAS_COORDS)

func _recenter_camera() -> void:
	var upper_left_pos:Vector2 = map_to_local(get_used_rect().position)
	var lower_right_pos:Vector2 = map_to_local(get_used_rect().end)
	camera.position = lerp(upper_left_pos, lower_right_pos, 0.5) - tile_set.tile_size * 0.5

func _spawn_game_piece(map_position:Vector2i, letter:String) -> GamePiece:
	assert(game_pieces[Game.map_to_index(map_position)] == null)
	var gp:GamePiece = game_piece_scene.instantiate()
	game_pieces[Game.map_to_index(map_position)] = gp
	add_child(gp)
	gp.position = map_to_local(map_position)
	gp.letter = letter
	return gp

func _clear_game_pieces() -> void:
	for piece:GamePiece in game_pieces:
		remove_child(piece)
		piece.queue_free()
	game_pieces.clear()
	game_pieces.resize(Game.board_width * Game.board_height)
	var lost_pieces:Array = get_children().filter(func(it): return it is GamePiece)
	for piece:GamePiece in lost_pieces:
		remove_child(piece)
		piece.queue_free()

func _erase_letter(map_pos:Vector2i) -> void:
	var piece:GamePiece = game_pieces[Game.map_to_index(map_pos)]
	game_pieces[Game.map_to_index(map_pos)] = null
	remove_child(piece)
	piece.queue_free()

# ================================================================
# Input Handling

func _input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		_input_mouse_button(event)

func _input_mouse_button(event:InputEventMouseButton) -> void:
	if event.is_pressed() && !mouse_was_pressed:
		_on_mouse_down()
	if event.is_released() && mouse_was_pressed:
		_on_mouse_up()
	mouse_was_pressed = event.is_pressed()

func _on_mouse_down() -> void:
	mouse_down_map_position = local_to_map(get_local_mouse_position())

func _on_mouse_up() -> void:
	mouse_up_map_position = local_to_map(get_local_mouse_position())
	if mouse_down_map_position == mouse_up_map_position:
		_on_mouse_click(mouse_up_map_position)
	else:
		_on_mouse_drag(mouse_down_map_position, mouse_up_map_position)
	mouse_down_map_position = Vector2i.MIN
	mouse_up_map_position = Vector2i.MIN

func _on_mouse_click(map_position:Vector2i) -> void:
	# Select if none selected
	if selected_piece_map_position == Vector2i.MIN:
		selected_piece_map_position = map_position
		return
	# Clicking again deselects
	if selected_piece_map_position == map_position:
		selected_piece_map_position = Vector2i.MIN
		return
	# Change selection if clicked cell is diagonal or not touching.
	if (map_position - selected_piece_map_position).length_squared() != 1:
		selected_piece_map_position = map_position
		return
	# Swap!
	var from_pos:Vector2i = selected_piece_map_position
	selected_piece_map_position = Vector2i.MIN
	Game.swap(from_pos, map_position)

func _on_mouse_drag(start_map_position:Vector2i, end_map_position:Vector2i) -> void:
	# Treat a zero-distance drag as a click.
	if (end_map_position - start_map_position).length_squared() != 1:
		_on_mouse_click(end_map_position)
		return
	# Ignore drags to cells that are diagonal or not touching.
	if (end_map_position - start_map_position).length_squared() != 1:
		return
	# Swap!
	selected_piece_map_position = Vector2i.MIN
	Game.swap(start_map_position, end_map_position)

# ================================================================
# Animations

func _swap_letter(start_map_pos:Vector2i, end_map_pos:Vector2i) -> void:
	var start_index:int = Game.map_to_index(start_map_pos)
	var end_index:int = Game.map_to_index(end_map_pos)
	game_pieces[start_index].swap_to(map_to_local(end_map_pos))
	game_pieces[end_index].swap_to(map_to_local(start_map_pos))
	var buffer:GamePiece = game_pieces[start_index]
	game_pieces[start_index] = game_pieces[end_index]
	game_pieces[end_index] = buffer

func _score_letter(map_pos:Vector2i, letter:String, delay_seconds:float) -> void:
	var piece:GamePiece = game_piece_scene.instantiate()
	scoring_game_pieces.push_back(piece)
	add_child(piece)
	move_child(piece, 0)
	piece.scoring_completed.connect(_on_scoring_completed)
	piece.position = map_to_local(map_pos)
	piece.letter = letter
	piece.play_score_animation(delay_seconds)

func _on_scoring_completed(piece:GamePiece) -> void:
	remove_child(piece)
	piece.queue_free()
	scoring_game_pieces.erase(piece)
	if scoring_game_pieces.is_empty():
		Game.on_all_pieces_scored()
