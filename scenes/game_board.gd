extends TileMapLayer

class_name GameBoard

const TILE_SOURCE_ID:int = 0
const TILE_ATLAS_COORDS:Vector2i = Vector2i(0, 0)

const MINIMUM_WORD_LENGTH:int = 3

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

func _ready() -> void:
	pass

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
	swap(from_pos, map_position)

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

# Checks for word matches horizontally and vertically.
# A word that is fully contained by another (larger) word will be ignored.
# Words that partially overlap will both count.
func check_for_words() -> void:
	var horizontal_words:Array[Dictionary] = []
	for y in board_height:
		horizontal_words.append_array(_check_for_words_in_row(y))
	var vertical_words:Array[Dictionary] = []
	for x in board_width:
		vertical_words.append_array(_check_for_words_in_column(x))
	if horizontal_words.is_empty() && vertical_words.is_empty():
		return
	print("Found %s words." % [horizontal_words.size() + vertical_words.size()])

func _check_for_words_in_row(y:int) -> Array[Dictionary]:
	var words:Array[Dictionary] = []
	# Capture the entire line's contents as a string. We will examine substrings of this string.
	var line:String = ""
	for x in board_width:
		line += game_pieces[map_to_index(Vector2i(x, y))].letter
	# Look for words. Start big, then look small
	# For board width 10 and word length 3, this is (0..7)
	for start in line.length() - (MINIMUM_WORD_LENGTH - 1):
		# For board width 10 and word length 3, this goes from (10..3) to (3..3)
		for word_length in range(line.length() - start, (MINIMUM_WORD_LENGTH - 1), -1):
			var row_slice:String = line.substr(start, word_length)
			# Ignore if not a word.
			if !Words.is_word(row_slice):
				continue
			# Ignore if word is contained within an existing word.
			var containing_index:int = words.find_custom(
				func(it): return range_contains_range(it[&"start"].x, it[&"length"], start, word_length)
			)
			if containing_index >= 0:
				continue
			# New word found!
			print("Found word '%s' between %s and %s!" % [
				row_slice, Vector2i(start, y), Vector2i(start + word_length - 1, y)
			])
			words.push_back({
				&"word": row_slice, &"start": Vector2i(start, y), &"length": word_length
			})
			break
	return words

func _check_for_words_in_column(x:int) -> Array[Dictionary]:
	var words:Array[Dictionary] = []
	# Capture the entire line's contents as a string. We will examine substrings of this string.
	var line:String = ""
	for y in board_height:
		line += game_pieces[map_to_index(Vector2i(x, y))].letter
	# Look for words. Start big, then look small
	for start in line.length() - (MINIMUM_WORD_LENGTH - 1):
		for word_length in range(line.length() - start, (MINIMUM_WORD_LENGTH - 1), -1):
			var row_slice:String = line.substr(start, word_length)
			# Ignore if not a word.
			if !Words.is_word(row_slice):
				continue
			# Ignore if word is contained within an existing word.
			var containing_index:int = words.find_custom(
				func(it): return range_contains_range(it[&"start"].y, it[&"length"], start, word_length)
			)
			if containing_index >= 0:
				continue
			# New word found!
			print("Found word '%s' between %s and %s!" % [
				row_slice, Vector2i(x, start), Vector2i(x, start + word_length - 1)
			])
			words.push_back({
				&"word": row_slice, &"start": Vector2i(x, start), &"length": word_length
			})
			break
	return words

func range_contains_range(a0:int, al:int, b0:int, bl:int) -> bool:
	return a0 <= b0 && (b0 + bl) <= (a0 + al)
