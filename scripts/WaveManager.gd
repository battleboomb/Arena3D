extends Node
## 웨이브 구성표대로 게이트에서 적을 하나씩 내보내고, 전멸하면 쉬었다가 다음 웨이브를 시작한다.

signal wave_started(number: int, total: int)
signal remaining_changed(remaining: int)
signal all_waves_cleared

## 웨이브별 마릿수 (x = 근거리, y = 원거리, z = 덩치)
@export var waves: Array[Vector3i] = [Vector3i(6, 0, 0), Vector3i(6, 3, 0), Vector3i(6, 4, 2)]
@export var melee_scene: PackedScene
@export var ranged_scene: PackedScene
@export var brute_scene: PackedScene
@export var start_delay := 1.0
@export var rest_time := 3.0
@export var spawn_interval := 0.5
## 플레이어와 이 거리 이상 떨어진 스폰 지점에서만 나온다.
@export var min_spawn_distance := 10.0
@export var player_path: NodePath
@export var enemies_path: NodePath
@export var spawn_points_path: NodePath

## 지금 웨이브 번호(1부터)
var current_wave := 0
var kills := 0
## 첫 웨이브 전부터 승리·패배까지 걸린 시간(초)
var elapsed := 0.0
var remaining := 0

var _queue: Array[PackedScene] = []
var _timer := 0.0
var _resting := true
var _running := true

@onready var _player: Player = get_node(player_path)
@onready var _enemies: Node3D = get_node(enemies_path)
@onready var _spawn_points: Array[Node] = get_node(spawn_points_path).get_children()


func _ready() -> void:
	_timer = start_delay
	_player.died.connect(func() -> void: _running = false)


func _physics_process(delta: float) -> void:
	if not _running:
		return
	elapsed += delta
	_timer -= delta
	if _resting:
		if _timer <= 0.0:
			_start_wave()
	elif not _queue.is_empty() and _timer <= 0.0:
		_spawn(_queue.pop_back())
		_timer = spawn_interval


func _start_wave() -> void:
	_resting = false
	current_wave += 1
	var counts := waves[current_wave - 1]
	_queue.clear()
	for i in counts.x:
		_queue.append(melee_scene)
	for i in counts.y:
		_queue.append(ranged_scene)
	for i in counts.z:
		_queue.append(brute_scene)
	_queue.shuffle()
	remaining = _queue.size()
	_timer = 0.0
	wave_started.emit(current_wave, waves.size())
	remaining_changed.emit(remaining)
	if remaining == 0:
		_on_wave_cleared()


func _spawn(scene: PackedScene) -> void:
	var enemy: Enemy = scene.instantiate()
	enemy.position = _pick_spawn_point()
	_enemies.add_child(enemy)
	enemy.reset_physics_interpolation()
	enemy.died.connect(_on_enemy_died)


func _pick_spawn_point() -> Vector3:
	var far: Array[Vector3] = []
	var farthest := Vector3.ZERO
	var farthest_dist := -1.0
	for point: Node3D in _spawn_points:
		var dist := point.global_position.distance_to(_player.global_position)
		if dist >= min_spawn_distance:
			far.append(point.global_position)
		if dist > farthest_dist:
			farthest_dist = dist
			farthest = point.global_position
	return far.pick_random() if not far.is_empty() else farthest


func _on_enemy_died(_enemy: Enemy) -> void:
	kills += 1
	remaining -= 1
	remaining_changed.emit(remaining)
	if remaining <= 0 and _queue.is_empty():
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	if current_wave >= waves.size():
		_running = false
		all_waves_cleared.emit()
	else:
		_resting = true
		_timer = rest_time
