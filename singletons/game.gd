extends Node

const STARTING_LETTERS:Array = ["A", "E", "I", "O", "R", "S", "T"]

const WORD_SCORE_DELAY:float = 0.5

var board_width:int = 0
var board_height:int = 0
var board_letters:Array = []

var available_letters:Array = STARTING_LETTERS

signal board_resized(old_width:int, old_height:int)
signal letter_added(map_pos:Vector2i, letter:String)
signal letter_swapped(from_map_pos:Vector2i, to_map_pos:Vector2i)
signal letter_scored(map_pos:Vector2i, letter:String, delay_seconds:float)
signal letter_erased(map_pos:Vector2i)

# ================================================================

func map_to_index(map_pos:Vector2i) -> int:
	return map_pos.y * board_width + map_pos.x

func get_letter_at(map_pos:Vector2i) -> String:
	return board_letters[map_to_index(map_pos)]

func set_size(width:int, height:int) -> void:
	var old_width:int = board_width
	var old_height:int = board_height
	board_width = width
	board_height = height
	board_letters.clear()
	board_letters.resize(board_width * board_height)
	board_resized.emit(old_width, old_height)
	fill_holes()

func fill_holes() -> void:
	for x in board_width:
		for y in board_height:
			var map_pos:Vector2i = Vector2i(x, y)
			if board_letters[map_to_index(map_pos)] == null:
				var letter:String = available_letters.pick_random()
				board_letters[map_to_index(map_pos)] = letter
				letter_added.emit(map_pos, letter)
	# TODO: letters should fall as if by gravity
	# TODO: new letters should fill holes after/while existing letters fall
	# TODO: wait for letters to finish falling before checking for words
	check_for_words()

func swap(start_map_position:Vector2i, end_map_position:Vector2i) -> void:
	var start_index:int = map_to_index(start_map_position)
	var end_index:int = map_to_index(end_map_position)
	var buffer:String = board_letters[start_index]
	board_letters[start_index] = board_letters[end_index]
	board_letters[end_index] = buffer
	letter_swapped.emit(start_map_position, end_map_position)
	letter_swapped.emit(end_map_position, start_map_position)
	# TODO: wait for letters to finish swapping before checking for words
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
	var delay_seconds:float = 0.0
	for word:Dictionary in horizontal_words:
		score_word(word[&"start"], word[&"length"], &"horizontal", delay_seconds)
		delay_seconds += WORD_SCORE_DELAY
	for word:Dictionary in vertical_words:
		score_word(word[&"start"], word[&"length"], &"vertical", delay_seconds)
		delay_seconds += WORD_SCORE_DELAY
	for word:Dictionary in horizontal_words:
		erase_word(word[&"start"], word[&"length"], &"horizontal")
	for word:Dictionary in vertical_words:
		erase_word(word[&"start"], word[&"length"], &"vertical")

func on_all_pieces_scored() -> void:
	fill_holes()

func _check_for_words_in_row(y:int) -> Array[Dictionary]:
	var words:Array[Dictionary] = []
	# Capture the entire line's contents as a string. We will examine substrings of this string.
	var line:String = ""
	for x in board_width:
		line += board_letters[map_to_index(Vector2i(x, y))]
	# Look for words. Start big, then look small
	# For board width 10 and word length 3, this is (0..7)
	for start in line.length() - (Words.MINIMUM_WORD_LENGTH - 1):
		# For board width 10 and word length 3, this goes from (10..3) to (3..3)
		for word_length in range(line.length() - start, (Words.MINIMUM_WORD_LENGTH - 1), -1):
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
		line += board_letters[map_to_index(Vector2i(x, y))]
	# Look for words. Start big, then look small
	for start in line.length() - (Words.MINIMUM_WORD_LENGTH - 1):
		for word_length in range(line.length() - start, (Words.MINIMUM_WORD_LENGTH - 1), -1):
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

func score_word(start:Vector2i, word_length:int, direction:StringName = &"horizontal", delay_seconds:float = 0.0) -> void:
	assert(Rect2i(0, 0, board_width, board_height).has_point(start))
	assert(word_length >= Words.MINIMUM_WORD_LENGTH)
	assert([&"horizontal", &"vertical"].has(direction))
	var dir_vector:Vector2i = Vector2i.RIGHT
	if direction == &"vertical":
		dir_vector = Vector2i.DOWN
	for i in word_length:
		var piece_map_pos:Vector2i = start + dir_vector * i
		var letter:String = board_letters[map_to_index(piece_map_pos)]
		letter_scored.emit(piece_map_pos, letter, delay_seconds)

func erase_word(start:Vector2i, word_length:int, direction:StringName = &"horizontal") -> void:
	assert(Rect2i(0, 0, board_width, board_height).has_point(start))
	assert(word_length >= Words.MINIMUM_WORD_LENGTH)
	assert([&"horizontal", &"vertical"].has(direction))
	var dir_vector:Vector2i = Vector2i.RIGHT
	if direction == &"vertical":
		dir_vector = Vector2i.DOWN
	for i in word_length:
		var piece_map_pos:Vector2i = start + dir_vector * i
		if board_letters[map_to_index(piece_map_pos)]:
			board_letters[map_to_index(piece_map_pos)] = null
			letter_erased.emit(piece_map_pos)
