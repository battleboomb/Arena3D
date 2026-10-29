class_name Effects
extends Node3D
## 짧은 연출(클릭 원, 칼 부채꼴, 먼지 원, 타격)을 만든다.
## 메시·머티리얼은 한 번만 만들어 재사용하고, 사라지는 효과는 인스턴스별 transparency로 준다.

static var instance: Effects

## 게임 시작 때 한 번 그려서 셰이더 컴파일 멈춤을 미리 없앨 씬들(적, 투사체).
@export var warmup_scenes: Array[PackedScene] = []

var ring_mesh: TorusMesh
var disc_mesh: CylinderMesh
var sphere_mesh: SphereMesh
var _fan_meshes := {}
var _materials := {}


func _enter_tree() -> void:
	instance = self
	ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.82
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 4
	disc_mesh = CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.02
	disc_mesh.radial_segments = 32
	disc_mesh.rings = 1
	sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	sphere_mesh.radial_segments = 12
	sphere_mesh.rings = 6


func _ready() -> void:
	_warmup.call_deferred()


## 색마다 한 번만 만드는 반투명 무광 머티리얼.
func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = color
		_materials[color] = mat
	return _materials[color]


func ring(pos: Vector3, radius: float, color: Color, duration := 0.3) -> void:
	var xform := Transform3D(Basis.from_scale(Vector3(radius, 0.5, radius)), pos + Vector3.UP * 0.05)
	_spawn(ring_mesh, material(color), xform, duration)


func disc(pos: Vector3, radius: float, color: Color, duration := 0.3) -> void:
	var xform := Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), pos + Vector3.UP * 0.04)
	_spawn(disc_mesh, material(color), xform, duration, 1.3)


func fan(pos: Vector3, dir: Vector3, radius: float, angle_deg: float, color: Color, duration := 0.1) -> void:
	if not _fan_meshes.has(angle_deg):
		_fan_meshes[angle_deg] = _build_fan(angle_deg)
	var basis := Basis.looking_at(dir).scaled_local(Vector3(radius, 1.0, radius))
	_spawn(_fan_meshes[angle_deg], material(color), Transform3D(basis, pos + Vector3.UP * 0.1), duration)


func burst(pos: Vector3, radius: float, color: Color, duration := 0.2) -> void:
	var xform := Transform3D(Basis.from_scale(Vector3.ONE * radius * 0.5), pos)
	_spawn(sphere_mesh, material(color), xform, duration, 2.0)


func _spawn(mesh: Mesh, mat: Material, xform: Transform3D, duration: float, grow := 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(mi)
	mi.global_transform = xform
	var tween := mi.create_tween().set_parallel()
	tween.tween_property(mi, "transparency", 1.0, duration).from(0.0)
	if grow != 1.0:
		tween.tween_property(mi, "scale", mi.scale * grow, duration)
	tween.chain().tween_callback(mi.queue_free)


func _build_fan(angle_deg: float) -> ArrayMesh:
	var half := deg_to_rad(angle_deg) * 0.5
	var segments := 12
	var verts := PackedVector3Array()
	for i in segments:
		var a0 := -half + 2.0 * half * i / segments
		var a1 := -half + 2.0 * half * (i + 1) / segments
		verts.append(Vector3.ZERO)
		verts.append(Vector3(sin(a0), 0.0, -cos(a0)))
		verts.append(Vector3(sin(a1), 0.0, -cos(a1)))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 적·투사체·이펙트를 바닥 아래에 몇 프레임 그려 셰이더를 미리 컴파일한다.
func _warmup() -> void:
	var hidden_pos := Vector3(0.0, -3.0, 0.0)
	var nodes: Array[Node] = []
	for scene in warmup_scenes:
		var node := scene.instantiate()
		node.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(node)
		node.remove_from_group("enemies")
		if node is CollisionObject3D:
			node.collision_layer = 0
			node.collision_mask = 0
		node.global_position = hidden_pos
		var bar := node.get_node_or_null("HealthBar")
		if bar:
			bar.visible = true
		nodes.append(node)
	ring(hidden_pos, 1.0, Color.WHITE, 0.1)
	fan(hidden_pos, Vector3.FORWARD, 1.0, 90.0, Color.WHITE, 0.1)
	burst(hidden_pos, 1.0, Color.WHITE, 0.1)
	for i in 3:
		await get_tree().process_frame
	for node in nodes:
		node.queue_free()
