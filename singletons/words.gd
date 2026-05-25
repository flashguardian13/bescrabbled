extends Node

const WORDS_PATH:String = "res://data/scrabble_words.txt"
var words:Array

func _ready():
	assert(FileAccess.file_exists(WORDS_PATH), "File not found: %s" % WORDS_PATH)
	var file:FileAccess = FileAccess.open(WORDS_PATH, FileAccess.READ)
	assert(file != null, "Error opening file '%s': %s" % [WORDS_PATH, FileAccess.get_open_error()])
	var word_regex:RegEx = RegEx.create_from_string("[A-Z]+")
	var matches:Array = word_regex.search_all(file.get_as_text())
	words = matches.map(func(it): return it.get_string())

func is_word(str:String) -> bool:
	return words.has(str)
