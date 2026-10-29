class_name Projectile
extends Area3D
## 직선으로 날아가는 투사체(창, 화살). 처음 맞은 대상 하나에 피해를 주고 사라진다.
## 무엇을 맞힐지는 씬의 collision_mask가 정한다(창 = world + enemy, 화살 = world + player).

@export var damage := 15.0
@export var speed := 12.0
@export var max_distance := 12.0
@export var hit_color := Color(1.0, 0.9, 0.6, 0.8)

var direction := Vector3.FORWARD
var _travelled := 0.0
var _done := false


## 투사체들이 들어가는 Main의 Projectiles 노드.
static func container(from: Node) -> Node:
	return from.get_tree().current_scene.get_node("Projectiles")


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(from: Vector3, dir: Vector3) -> void:
	direction = dir.normalized()
	global_transform = Transform3D(Basis.looking_at(direction), from)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += direction * step
	_travelled += step
	if _travelled >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _done:
		return
	# 구르기 무적 중인 플레이어처럼 피해를 받지 않으면 그대로 지나간다.
	if body.has_method("take_damage") and not body.take_damage(damage, global_position - direction):
		return
	_done = true
	Effects.instance.burst(global_position, 0.35, hit_color)
	queue_free()
