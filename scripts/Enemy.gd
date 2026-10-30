class_name Enemy
extends CharacterBody3D
## 적 3종 공통: 체력, 상태 머신(추적 → 예비 동작 → 공격 → 대기), 피격, 사망.
## 이 스크립트 그대로가 근거리(졸개)이고, 원거리·덩치는 상속해서 차이점만 덮어쓴다.

signal died(enemy: Enemy)

enum State { CHASE, WINDUP, RECOVER, IDLE, DEAD }

const BAR_WIDTH := 0.9
const BAR_HEIGHT := 0.1

@export var max_health := 30.0
@export var move_speed := 3.5
## 이 거리 안에 들면 예비 동작을 시작한다.
@export var attack_range := 1.2
## 예비 동작이 끝날 때 플레이어가 이 거리 밖이면 빗나간다.
@export var hit_range := 1.6
@export var windup_time := 0.3
@export var attack_damage := 10.0
@export var attack_interval := 1.0
## 공격 직후 제자리에 서 있는 시간
@export var recover_time := 0.3
@export var knockback_immune := false
@export var knockback_time := 0.15
## 칼 사거리에 더해지는 몸 반지름
@export var hit_radius := 0.35
@export var flash_time := 0.1
@export var death_time := 0.3
@export var health_bar_height := 1.8
@export var windup_material: Material
@export var flash_material: Material

@export_group("모델")
## 갑옷·치마·투구 깃 같은 소속 부위에 칠할 색
@export var tint := Color(0.85, 0.16, 0.14)
@export var show_sword := false
@export var attack_animation := "punch"
## 서 있을 때 첫 프레임에 멈춰 둘 애니메이션(팔 내린 자세)
@export var idle_animation := "punch"
## 공격 애니메이션에서 타격이 들어가는 시점(초). 예비 동작이 끝날 때 여기에 닿도록 속도를 맞춘다.
@export var attack_impact_time := 0.4
@export var run_anim_speed := 1.2

const TINT_PARTS := ["Chest_Armor", "Shoulder_Armor_L", "Shoulder_Armor_R", "Skirt", "Helmet_Crest",
		"Arm_Guard_L", "Arm_Guard_R", "Leg_Guard_L", "Leg_Guard_R"]

static var _bar_texture: Texture2D
static var _tint_materials := {}

var health: float
var state := State.CHASE
var player: Player

var _state_time := 0.0
var _attack_cooldown := 0.0
var _flash_left := 0.0
var _knock_velocity := Vector3.ZERO
var _knock_left := 0.0
var _health_bar: Node3D
var _bar_fill: Sprite3D
var _meshes: Array[MeshInstance3D] = []
var _base_materials: Array[Material] = []
var _override: Material
var _base_pose := ""

@onready var body: Node3D = $Body
@onready var _anim: AnimationPlayer = $Body/Model/AnimationPlayer


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	_make_health_bar()
	_setup_model()


func _process(_delta: float) -> void:
	if state == State.DEAD or state == State.WINDUP or state == State.RECOVER:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1 and _knock_left <= 0.0
	_set_base_pose("run" if moving else "idle")


func is_alive() -> bool:
	return state != State.DEAD


func take_damage(amount: float, from_position: Vector3, knockback := 0.0) -> bool:
	if state == State.DEAD:
		return false
	health -= amount
	_flash_left = flash_time
	_update_health_bar()
	if health <= 0.0:
		_die()
		return true
	if knockback > 0.0 and not knockback_immune:
		var away := global_position - from_position
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = body.global_basis.z
		_knock_velocity = away.normalized() * (knockback / knockback_time)
		_knock_left = knockback_time
		if state == State.WINDUP:
			_on_windup_end()
			state = State.CHASE
	return true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_cooldown -= delta
	_flash_left -= delta
	_update_material()
	if _knock_left > 0.0:
		_knock_left -= delta
		velocity = _knock_velocity
		move_and_slide()
		return
	if player == null or player.dead:
		if state == State.WINDUP:
			_on_windup_end()
		state = State.IDLE
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	match state:
		State.CHASE:
			var dir := _chase_direction(to_player, dist)
			if dir != Vector3.ZERO:
				dir = Steering.avoid(self, dir)
				_face(dir)
			else:
				_face(to_player)
			velocity = dir * move_speed
			move_and_slide()
			if _attack_cooldown <= 0.0 and _can_attack(dist):
				state = State.WINDUP
				_state_time = 0.0
				_play_attack_animation()
				_on_windup_start()
		State.WINDUP:
			_face(to_player)
			_state_time += delta
			_on_windup_progress(clampf(_state_time / windup_time, 0.0, 1.0))
			if _state_time >= windup_time:
				_on_windup_end()
				_attack(to_player, dist)
				_attack_cooldown = attack_interval
				state = State.RECOVER
				_state_time = 0.0
		State.RECOVER:
			_state_time += delta
			if _state_time >= recover_time:
				state = State.CHASE


# --- 종류별로 덮어쓰는 부분 ---

## 추적 중 움직일 방향. 기본은 플레이어에게 곧장 달려든다.
func _chase_direction(to_player: Vector3, _dist: float) -> Vector3:
	return to_player.normalized()


func _can_attack(dist: float) -> bool:
	return dist <= attack_range


func _on_windup_start() -> void:
	pass


func _on_windup_progress(_t: float) -> void:
	pass


func _on_windup_end() -> void:
	pass


## 예비 동작이 끝나는 순간 호출된다. 기본은 근접 공격(범위 밖이면 헛침).
func _attack(_to_player: Vector3, dist: float) -> void:
	if dist <= hit_range:
		player.take_damage(attack_damage, global_position)


# --- 공통 처리 ---

func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		body.rotation.y = atan2(-dir.x, -dir.z)


## 소속 부위에 tint 색 머티리얼을 입히고 칼은 show_sword일 때만 보인다.
func _setup_model() -> void:
	if not _tint_materials.has(tint):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.8
		_tint_materials[tint] = mat
	for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "Sword":
			mesh.visible = show_sword
		var base: Material = _tint_materials[tint] if mesh.name in TINT_PARTS else null
		mesh.material_override = base
		_meshes.append(mesh)
		_base_materials.append(base)


## 움직이면 달리기, 서 있으면 idle_animation 첫 프레임으로 멈춘다.
func _set_base_pose(pose: String) -> void:
	if pose == _base_pose:
		return
	_base_pose = pose
	if pose == "run":
		_anim.play("run", 0.1, run_anim_speed)
	else:
		_anim.play(idle_animation, 0.1)
		_anim.seek(0.0, true)
		_anim.pause()


func _play_attack_animation() -> void:
	_base_pose = ""
	_anim.stop()
	_anim.play(attack_animation, 0.05, attack_impact_time / windup_time)


## 피격 번쩍임·예비 동작 색은 몸 전체를 덮고, 끝나면 부위별 원래 머티리얼로 돌린다.
func _set_override(mat: Material) -> void:
	if mat == _override:
		return
	_override = mat
	for i in _meshes.size():
		_meshes[i].material_override = mat if mat != null else _base_materials[i]


func _update_material() -> void:
	var mat: Material = null
	if _flash_left > 0.0:
		mat = flash_material
	elif state == State.WINDUP:
		mat = windup_material
	_set_override(mat)


func _die() -> void:
	state = State.DEAD
	_on_windup_end()
	collision_layer = 0
	collision_mask = 0
	_health_bar.visible = false
	_set_override(null)
	_anim.pause()
	died.emit(self)
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(body, "scale", Vector3.ONE * 0.01, death_time)
	tween.tween_callback(queue_free)


## 머리 위 체력 바: 공유 텍스처를 쓰는 빌보드 Sprite3D 두 장. 첫 피해 전까지는 숨긴다.
func _make_health_bar() -> void:
	if _bar_texture == null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_bar_texture = ImageTexture.create_from_image(image)
	_health_bar = Node3D.new()
	_health_bar.name = "HealthBar"
	_health_bar.position.y = health_bar_height
	_health_bar.visible = false
	add_child(_health_bar)
	_make_bar_sprite(Color(0.08, 0.08, 0.08, 0.85), 0)
	_bar_fill = _make_bar_sprite(Color(0.92, 0.18, 0.15, 1.0), 1)


func _make_bar_sprite(color: Color, priority: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = _bar_texture
	sprite.pixel_size = 0.25
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.modulate = color
	sprite.render_priority = priority
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.scale = Vector3(BAR_WIDTH, BAR_HEIGHT, 1.0)
	_health_bar.add_child(sprite)
	return sprite


func _update_health_bar() -> void:
	var ratio := clampf(health / max_health, 0.0, 1.0)
	_health_bar.visible = true
	_bar_fill.scale.x = BAR_WIDTH * maxf(ratio, 0.001)
	# 빌보드라 화면 오른쪽(카메라 x축) 방향으로 밀어 왼쪽 끝을 맞춘다.
	var cam_right := get_viewport().get_camera_3d().global_basis.x
	_bar_fill.position = -cam_right * BAR_WIDTH * (1.0 - ratio) * 0.5
