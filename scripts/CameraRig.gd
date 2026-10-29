extends Node3D
## 카메라를 플레이어 쪽으로 부드럽게 따라가게 한다. 자식 Camera3D가 쿼터뷰 각도와 거리를 갖는다.

@export var target_path: NodePath
@export var follow_speed := 6.0

@onready var _target: Node3D = get_node(target_path)


func _ready() -> void:
	global_position = _flat(_target.global_position)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_flat(_target.global_position), 1.0 - exp(-follow_speed * delta))


func _flat(pos: Vector3) -> Vector3:
	return Vector3(pos.x, 0.0, pos.z)
