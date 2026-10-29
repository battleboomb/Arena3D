extends Enemy
## 원거리(궁수): 플레이어와 7~9 m 거리를 유지하며 조준 후 화살을 쏜다.

@export var min_distance := 7.0
@export var max_distance := 9.0
@export var arrow_scene: PackedScene


func _chase_direction(to_player: Vector3, dist: float) -> Vector3:
	if dist < min_distance:
		return -to_player.normalized()
	if dist > max_distance:
		return to_player.normalized()
	return Vector3.ZERO


## min_distance − 1 m보다 가까우면 쏘지 않고 먼저 물러난다.
func _can_attack(dist: float) -> bool:
	return dist >= min_distance - 1.0 and dist <= max_distance + 1.0


## 조준이 끝나는 순간의 플레이어 방향으로 직선 발사한다.
func _attack(to_player: Vector3, _dist: float) -> void:
	var dir := to_player.normalized()
	var arrow: Projectile = arrow_scene.instantiate()
	Projectile.container(self).add_child(arrow)
	arrow.launch(global_position + dir * 0.5 + Vector3.UP * 0.8, dir)
