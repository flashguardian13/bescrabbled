extends Node2D

class_name GamePiece

@onready var light:PointLight2D = $PointLight2D
@onready var label:Label = $Label
@onready var animator:AnimationPlayer = $AnimationPlayer

signal scoring_completed(piece:GamePiece)

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

func play_score_animation(delay_seconds:float = 0.0) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	animator.play(&"score")

func _on_animation_player_animation_finished(anim_name:StringName):
	if anim_name == &"score":
		scoring_completed.emit(self)
