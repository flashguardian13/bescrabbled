extends Sprite2D

class_name GamePiece

@onready var light:PointLight2D = $PointLight2D
@onready var label:Label = $Label

var letter:String:
	get:
		return letter
	set(value):
		assert(value is String, "Expected String but received '%s'!" % value)
		assert(value.length() == 1, "Expected String to be a single character, but received '%s'!" % value)
		if letter == value:
			return
		letter = value
		label.text = letter

func stop_glow() -> void:
	light.enabled = false

func start_glow() -> void:
	light.enabled = true

func swap_to(local_pos:Vector2) -> void:
	var tween:Tween = create_tween()
	tween.tween_property(self, "position", local_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
