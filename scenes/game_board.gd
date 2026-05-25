extends TileMapLayer

class_name GameBoard

const TILE_SOURCE_ID:int = 0
const TILE_ATLAS_COORDS:Vector2i = Vector2i(0, 0)

@onready var game_piece_scene:PackedScene = preload("res://scenes/game_piece.tscn")

@onready var camera:Camera2D = $Camera2D

var mouse_was_pressed:bool = false
var mouse_down_map_position:Vector2i = Vector2i.MIN
var mouse_up_map_position:Vector2i = Vector2i.MIN
var selected_piece_map_position:Vector2i = Vector2i.MIN:
	get:
		return selected_piece_map_position
	set(value):
		if selected_piece_map_position == value:
			return
		var board_rect:Rect2i = Rect2i(0, 0, board_width, board_height)
		if board_rect.has_point(selected_piece_map_position):
			game_pieces[map_to_index(selected_piece_map_position)].stop_glow()
		selected_piece_map_position = value
		if board_rect.has_point(selected_piece_map_position):
			game_pieces[map_to_index(selected_piece_map_position)].start_glow()

var board_width:int = 0
var board_height:int = 0
var game_pieces:Array = []

var available_letters:Array = ["A", "E", "I", "O", "R", "S", "T"]

# ================================================================
# Game Board and Piece Management

func set_size(width:int, height:int) -> void:
	board_width = width
	board_height = height
	_resize_board()
	_recenter_camera()

func _resize_board() -> void:
	_clear_game_pieces()
	clear()
	for x:int in board_width:
		for y:int in board_height:
			set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_ATLAS_COORDS)
			_spawn_game_piece(Vector2i(x, y))

func _recenter_camera() -> void:
	var upper_left_pos:Vector2 = map_to_local(get_used_rect().position)
	var lower_right_pos:Vector2 = map_to_local(get_used_rect().end)
	camera.position = lerp(upper_left_pos, lower_right_pos, 0.5) - tile_set.tile_size * 0.5

func map_to_index(map_position:Vector2i) -> int:
	return map_position.y * board_width + map_position.x

func _spawn_game_piece(map_position:Vector2i) -> GamePiece:
	var gp:GamePiece = game_piece_scene.instantiate()
	game_pieces[map_to_index(map_position)] = gp
	add_child(gp)
	gp.position = map_to_local(map_position)
	gp.letter = available_letters.pick_random()
	return gp

func _clear_game_pieces() -> void:
	for piece:GamePiece in game_pieces:
		remove_child(piece)
		piece.queue_free()
	game_pieces.clear()
	game_pieces.resize(board_width * board_height)
	var lost_pieces:Array = get_children().filter(func(it): return it is GamePiece)
	for piece:GamePiece in lost_pieces:
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
	print("Mouse clicked at %s" % [mouse_up_map_position])
	if selected_piece_map_position == map_position:
		selected_piece_map_position = Vector2i.MIN
	else:
		if selected_piece_map_position == Vector2i.MIN:
			selected_piece_map_position = map_position
		else:
			var from_pos:Vector2i = selected_piece_map_position
			selected_piece_map_position = Vector2i.MIN
			swap(from_pos, map_position)

func _on_mouse_drag(start_map_position:Vector2i, end_map_position:Vector2i) -> void:
	# Treat a zero-distance drag as a click.
	if (end_map_position - start_map_position).length_squared() != 1:
		_on_mouse_click(end_map_position)
		return
	# Ignore drags to cells that are diagonal or not touching.
	if (end_map_position - start_map_position).length_squared() != 1:
		return
	selected_piece_map_position = Vector2i.MIN
	swap(start_map_position, end_map_position)

func swap(start_map_position:Vector2i, end_map_position:Vector2i) -> void:
	var start_index:int = map_to_index(start_map_position)
	var end_index:int = map_to_index(end_map_position)
	game_pieces[start_index].swap_to(map_to_local(end_map_position))
	game_pieces[end_index].swap_to(map_to_local(start_map_position))
	var buffer:GamePiece = game_pieces[start_index]
	game_pieces[start_index] = game_pieces[end_index]
	game_pieces[end_index] = buffer
	check_for_words()

func check_for_words() -> void:
	for y in board_height:
		var row:String = ""
		for x in board_width:
			row += game_pieces[map_to_index(Vector2i(x, y))].letter
		for start_x in board_width - 2:
			for len in range(board_width - start_x, 2, -1):
				var word:String = row.substr(start_x, len)
				if Words.is_word(word):
					print("Found word '%s' between %s and %s!" % [word, Vector2i(start_x, y), Vector2i(start_x + len - 1, y)])
