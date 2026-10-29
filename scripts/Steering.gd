class_name Steering
## 기둥에 정면으로 막혀 미끄러질 방향이 없을 때 옆으로 살짝 틀어 비켜가는 방향을 구한다.
## 비스듬히 부딪히는 경우는 move_and_slide()가 알아서 미끄러지므로 그대로 둔다.


static func avoid(body: CharacterBody3D, dir: Vector3, look_ahead := 0.4) -> Vector3:
	var hit := KinematicCollision3D.new()
	if not body.test_move(body.global_transform, dir * look_ahead, hit):
		return dir
	var obstacle := hit.get_collider() as StaticBody3D
	if obstacle == null:
		return dir
	var normal := hit.get_normal()
	normal.y = 0.0
	if normal.length_squared() < 0.01:
		return dir
	normal = normal.normalized()
	if dir.dot(-normal) < 0.9:
		return dir
	# 진행 방향이 조금이라도 기운 쪽으로 돈다. 거의 정면이면 늘 같은 쪽으로 돌아
	# 매 프레임 좌우가 뒤집혀 제자리에서 떨지 않게 한다.
	var side := Vector3(-normal.z, 0.0, normal.x)
	if dir.dot(side) < -0.05:
		side = -side
	return (side + dir * 0.3).normalized()
