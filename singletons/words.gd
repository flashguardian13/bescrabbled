extends Node

const BAD_WORDS_PATH:String = "res://data/bad-words.txt"
const WORDS_PATH:String = "res://data/12dicts-6.0.2/International/3of6game.txt"

const MINIMUM_WORD_LENGTH:int = 3

var bad_words:Array
var word_tree:Dictionary[StringName, Array]

func _ready():
	_load_bad_words()
	_load_words_into_tree()

func _load_bad_words() -> void:
	bad_words.clear()
	assert(FileAccess.file_exists(BAD_WORDS_PATH), "File not found: %s" % BAD_WORDS_PATH)
	var file:FileAccess = FileAccess.open(BAD_WORDS_PATH, FileAccess.READ)
	assert(file != null, "Error opening file '%s': %s" % [BAD_WORDS_PATH, FileAccess.get_open_error()])
	bad_words = find_words_by_line(file)

func _load_words_into_tree() -> void:
	word_tree.clear()
	assert(FileAccess.file_exists(WORDS_PATH), "File not found: %s" % WORDS_PATH)
	var file:FileAccess = FileAccess.open(WORDS_PATH, FileAccess.READ)
	assert(file != null, "Error opening file '%s': %s" % [WORDS_PATH, FileAccess.get_open_error()])
	var words:Array = find_words_by_line(file)
	assert(words.size() > 100, "Expected more than a hundred words, but only found %s!" % words.size())
	for word:String in words:
		if word.length() < MINIMUM_WORD_LENGTH:
			continue
		if bad_words.has(word):
			continue
		var hash:StringName = hash_word(word)
		if !word_tree.has(hash):
			word_tree[hash] = []
		word_tree[hash].append(word)
	#_score_word_tree_branches()

func find_words_by_line(file:FileAccess) -> Array:
	var words:Array = []
	var invalid_characters:RegEx = RegEx.create_from_string("[^A-Z]")
	while file.get_position() < file.get_length():
		var line:String = file.get_line().strip_edges().to_upper()
		if line.length() < MINIMUM_WORD_LENGTH:
			continue
		if line.ends_with("$"):
			line = line.replace("$", "") # from less than three sources
		if line.ends_with("+"):
			line = line.replace("+", "") # signature word, added by curator
		if line.ends_with("^"):
			line = line.replace("^", "") # most common spelling
		if line.ends_with("&"):
			line = line.replace("&", "") # primarily non-American
		if line.ends_with("!"):
			line = line.replace("!", "") # neologisms (very new words)
		assert(invalid_characters.search(line) == null, "Dictionary word '%s' contains invalid characters!" % line)
		words.push_back(line)
	return words

func find_words_by_regex(file:FileAccess) -> Array:
	var word_regex:RegEx = RegEx.create_from_string("[A-Z]+")
	var matches:Array = word_regex.search_all(file.get_as_text())
	matches = matches.map(func(it): return it.get_string())
	matches = matches.filter(func(it): return it.length() >= MINIMUM_WORD_LENGTH)
	return matches

func hash_word(word:String) -> StringName:
	var letters_hash:Dictionary = {}
	for letter in word.split():
		letters_hash[letter] = true
	var letters:Array = letters_hash.keys()
	letters.sort()
	return "".join(letters)

func is_word(str:String) -> bool:
	var hash:StringName = hash_word(str)
	return word_tree.get(hash, []).has(str)

#func _score_word_tree_branches() -> void:
	#var scored_branches:Array[Array] = []
	#for word_hash in word_tree:
		#var score:float = 1.0 * word_tree[word_hash].size() / word_hash.length()
		#scored_branches.append([word_hash, score])
	#scored_branches.sort_custom(func(a, b): return b[1] < a[1])
	#for scored_branch in scored_branches.slice(0, 25):
		#print("%s: %s" % [scored_branch[1], scored_branch[0]])

#23.6: AERST
#18.4285714285714: AEINRST
#18.0: AEINST
#16.8333333333333: EINRST
#16.6: EINST
#15.8: AEPRS
#14.6666666666667: AEIRST
#14.6: EORST
#14.4: AELST
#13.4: EOPRS
