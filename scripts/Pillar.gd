@tool
extends StaticBody3D
## 콜로세움 돌기둥. 충돌은 몸통 원기둥(반지름 0.5 m)만 쓴다.

## 기둥 높이(m). 낮추면 부서진 기둥처럼 보인다.
@export_range(0.5, 5.0, 0.1) var height := 3.0:
	set(value):
		height = value
		_apply()
## 부서진 기둥이면 위 장식(주두)을 숨긴다.
@export var broken := false:
	set(value):
		broken = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	$Shaft.scale.y = height
	$Shaft.position.y = height * 0.5
	$Capital.visible = not broken
	$Capital.position.y = height + 0.15
	$CollisionShape3D.shape.height = height
	$CollisionShape3D.position.y = height * 0.5
