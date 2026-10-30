class_name Player
extends CharacterBody3D
## 검투사. WASD 이동, 좌클릭 근접 공격(칼이 없으면 주먹), 우클릭 창 던지기, Space 멀리 구르기.
## 공격과 구르기는 모두 마우스 커서 방향으로 나가고 쿨다운으로만 제한한다.

signal died
signal health_changed(current: float, maximum: float)

@export_group("이동")
@export var move_speed := 5.0

@export_group("체력")
@export var max_health := 100.0
@export var hurt_invulnerable_time := 0.5
@export var blink_interval := 0.06

@export_group("칼 공격")
@export var melee_damage := 20.0
@export var melee_range := 1.8
@export var melee_angle := 90.0
@export var melee_knockback := 1.0
@export var melee_cooldown := 0.4

@export_group("창 던지기")
@export var spear_scene: PackedScene
@export var spear_cooldown := 0.6

@export_group("멀리 구르기")
@export var roll_distance := 4.0
@export var roll_time := 0.25
@export var roll_invulnerable_after := 0.3
@export var roll_cooldown := 3.0

@export_group("공통")
## 칼·창을 쓰는 순간 제자리에 서 있는 시간
@export var attack_stand_time := 0.15
@export var dead_material: Material

@export_group("애니메이션")
## 공격 애니메이션을 이 시간 안에 끝나도록 빨리 돌린다.
@export var punch_anim_time := 0.45
@export var slash_anim_time := 0.55
@export var run_anim_speed := 1.2

var health: float
var dead := false
## 보물상자에서 칼을 얻으면 true. 그 전에는 칼 공격 대신 주먹질을 한다.
var has_sword := false
## 남은 쿨다운(초)
var cooldowns := {"melee": 0.0, "spear": 0.0, "roll": 0.0}
## 자동 테스트가 마우스 커서 대신 쓰는 조준점. 평소에는 null.
var aim_override: Variant = null

var _stand_time := 0.0
var _invulnerable_time := 0.0
var _hurt_time := 0.0
var _rolling := false
var _roll_dir := Vector3.ZERO
var _roll_speed := 0.0
var _roll_elapsed := 0.0
var _facing := Vector3.FORWARD
var _attack_anim_left := 0.0
## 지금 재생 중인 기본 동작("idle" 또는 "run")
var _base_pose := ""

@onready var body: Node3D = $Body
@onready var model: Node3D = $Body/Model
@onready var _anim: AnimationPlayer = $Body/Model/Gladiator/AnimationPlayer
@onready var _sword: Node3D = $Body/Model/Gladiator/Gladiator_Rig/Skeleton3D/hand_R/Sword


func _ready() -> void:
	health = max_health
	add_to_group("player")
	_sword.visible = false


func equip_sword() -> void:
	has_sword = true
	_sword.visible = true


func _process(delta: float) -> void:
	if dead:
		return
	_attack_anim_left -= delta
	if _attack_anim_left > 0.0:
		return
	var moving := _rolling or Vector2(velocity.x, velocity.z).length() > 0.1
	_set_base_pose("run" if moving else "idle")


## 걷기 없이 움직이면 달리기, 서 있으면 공격 애니메이션의 첫 프레임(팔 내린 자세)으로 멈춘다.
func _set_base_pose(pose: String) -> void:
	if pose == _base_pose:
		return
	_base_pose = pose
	if pose == "run":
		_anim.play("run", 0.1, run_anim_speed)
	else:
		_anim.play("punch", 0.1)
		_anim.seek(0.0, true)
		_anim.pause()


func _play_attack(anim_name: String, duration: float) -> void:
	_base_pose = ""
	_attack_anim_left = duration
	_anim.stop()
	_anim.play(anim_name, 0.05, _anim.get_animation(anim_name).length / duration)


func cooldown_total(skill: String) -> float:
	match skill:
		"melee":
			return melee_cooldown
		"spear":
			return spear_cooldown
		_:
			return roll_cooldown


func is_invulnerable() -> bool:
	return _rolling or _invulnerable_time > 0.0


func take_damage(amount: float, _from_position: Vector3) -> bool:
	if dead or is_invulnerable():
		return false
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()
	else:
		_invulnerable_time = hurt_invulnerable_time
		_hurt_time = hurt_invulnerable_time
	return true


## 커서가 가리키는 바닥(y = 0) 지점.
func get_aim_point() -> Vector3:
	if aim_override != null:
		return aim_override
	return _ground_point(get_viewport().get_mouse_position())


func _physics_process(delta: float) -> void:
	for skill in cooldowns:
		cooldowns[skill] = maxf(cooldowns[skill] - delta, 0.0)
	_invulnerable_time -= delta
	_stand_time -= delta
	_update_blink(delta)
	if dead:
		return
	if _rolling:
		_process_roll(delta)
		return
	if Input.is_action_just_pressed("roll") and cooldowns.roll <= 0.0:
		_start_roll()
		return
	if Input.is_action_pressed("attack_melee") and cooldowns.melee <= 0.0:
		_melee()
	elif Input.is_action_pressed("throw_spear") and cooldowns.spear <= 0.0:
		_throw_spear()
	_process_move()


func _process_move() -> void:
	if _stand_time > 0.0:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3.ZERO
	if input != Vector2.ZERO:
		dir = _screen_to_world(input)
	if dir != Vector3.ZERO:
		dir = Steering.avoid(self, dir)
		_face(dir)
	velocity = dir * move_speed
	move_and_slide()


func _melee() -> void:
	cooldowns.melee = melee_cooldown
	var dir := _aim_direction()
	_begin_attack_stand(dir)
	if has_sword:
		_play_attack("sword-slash", slash_anim_time)
	else:
		_play_attack("punch", punch_anim_time)
	var half_angle := deg_to_rad(melee_angle * 0.5)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_alive():
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		var dist := to_enemy.length()
		if dist > melee_range + enemy.hit_radius:
			continue
		if dist > 0.3 and dir.angle_to(to_enemy) > half_angle:
			continue
		enemy.take_damage(melee_damage, global_position, melee_knockback)
	Effects.instance.fan(global_position, dir, melee_range, melee_angle, Color(1, 1, 1, 0.45))


func _throw_spear() -> void:
	cooldowns.spear = spear_cooldown
	var dir := _aim_direction()
	_begin_attack_stand(dir)
	var spear: Projectile = spear_scene.instantiate()
	Projectile.container(self).add_child(spear)
	spear.launch(global_position + dir * 0.5 + Vector3.UP * 1.0, dir)


## 공격하는 순간 커서 쪽으로 몸을 돌리고 잠깐 제자리에 선다.
func _begin_attack_stand(dir: Vector3) -> void:
	_face(dir)
	_stand_time = attack_stand_time
	velocity = Vector3.ZERO


func _start_roll() -> void:
	var to_aim := get_aim_point() - global_position
	to_aim.y = 0.0
	var dist := minf(to_aim.length(), roll_distance)
	if dist < 0.3:
		to_aim = _facing
		dist = roll_distance
	_roll_dir = to_aim.normalized()
	_roll_speed = dist / roll_time
	_roll_elapsed = 0.0
	_rolling = true
	cooldowns.roll = roll_cooldown
	_face(_roll_dir)
	Effects.instance.disc(global_position, 0.7, Color(0.93, 0.85, 0.68, 0.7))


func _process_roll(delta: float) -> void:
	_roll_elapsed += delta
	velocity = _roll_dir * _roll_speed
	move_and_slide()
	model.rotation.x = -TAU * clampf(_roll_elapsed / roll_time, 0.0, 1.0)
	if _roll_elapsed >= roll_time:
		_rolling = false
		model.rotation.x = 0.0
		_invulnerable_time = maxf(_invulnerable_time, roll_invulnerable_after)
		Effects.instance.disc(global_position, 0.7, Color(0.93, 0.85, 0.68, 0.7))


func _die() -> void:
	dead = true
	velocity = Vector3.ZERO
	_anim.pause()
	body.visible = true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = dead_material
	model.rotation = Vector3(0.0, 0.0, PI * 0.5)
	model.position.y = 0.4
	died.emit()


func _update_blink(delta: float) -> void:
	if _hurt_time <= 0.0:
		return
	_hurt_time -= delta
	body.visible = dead or _hurt_time <= 0.0 or int(_hurt_time / blink_interval) % 2 == 0


func _face(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	_facing = dir.normalized()
	body.rotation.y = atan2(-_facing.x, -_facing.z)


func _aim_direction() -> Vector3:
	var to_aim := get_aim_point() - global_position
	to_aim.y = 0.0
	if to_aim.length() < 0.05:
		return _facing
	return to_aim.normalized()


## WASD 입력을 화면 기준 방향(W = 화면 위쪽)으로 바꾼다.
func _screen_to_world(input: Vector2) -> Vector3:
	var cam_basis := get_viewport().get_camera_3d().global_basis
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	return (right * input.x - forward * input.y).normalized()


func _ground_point(screen_pos: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
	return hit if hit != null else global_position
