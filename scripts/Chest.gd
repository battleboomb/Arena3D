extends Node3D
## 보물상자: 플레이어가 감지 영역에 들어오면 뚜껑 여는 애니메이션을 한 번만 재생한다.

@export var open_animation := "open"

var _opened := false

@onready var _animation: AnimationPlayer = $Model/AnimationPlayer


func _ready() -> void:
	$OpenArea.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _opened or not body is Player:
		return
	_opened = true
	_animation.play(open_animation)
