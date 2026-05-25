extends Node

const WORDS_PATH:String = "res://data/scrabble_words.txt"

var word_tree:Dictionary[StringName, Array]

func _ready():
	assert(FileAccess.file_exists(WORDS_PATH), "File not found: %s" % WORDS_PATH)
	var file:FileAccess = FileAccess.open(WORDS_PATH, FileAccess.READ)
	assert(file != null, "Error opening file '%s': %s" % [WORDS_PATH, FileAccess.get_open_error()])
	var word_regex:RegEx = RegEx.create_from_string("[A-Z]+")
	var matches:Array = word_regex.search_all(file.get_as_text())
	for match:RegExMatch in matches:
		var word:String = match.get_string()
		if word.length() < 3:
			continue
		var hash:StringName = hash_word(word)
		if !word_tree.has(hash):
			word_tree[hash] = []
		word_tree[hash].append(word)
	#_score_word_tree_branches()

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
