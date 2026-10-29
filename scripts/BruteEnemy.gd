extends Enemy
## 덩치: 느리게 쫓아오다가 바닥에 경고 원을 띄우고 범위 내려찍기. 넉백을 받지 않는다.

@export var slam_radius := 2.5
@export var warning_color := Color(0.95, 0.12, 0.1, 0.22)
@export var warning_fill_color := Color(0.95, 0.12, 0.1, 0.5)

var _warning_area: MeshInstance3D
var _warning_fill: MeshInstance3D


func _ready() -> void:
	super()
	_warning_area = _make_warning_disc(warning_color, 0.02)
	_warning_area.scale = Vector3(slam_radius, 1.0, slam_radius)
	_warning_fill = _make_warning_disc(warning_fill_color, 0.03)


func _on_windup_start() -> void:
	_warning_area.visible = true
	_warning_fill.visible = true
	_warning_fill.scale = Vector3(0.01, 1.0, 0.01)


## 안쪽 원이 차오르며 떨어지는 때를 보여준다.
func _on_windup_progress(t: float) -> void:
	var r := maxf(slam_radius * t, 0.01)
	_warning_fill.scale = Vector3(r, 1.0, r)


func _on_windup_end() -> void:
	_warning_area.visible = false
	_warning_fill.visible = false


func _attack(_to_player: Vector3, dist: float) -> void:
	Effects.instance.disc(global_position, slam_radius, Color(1.0, 0.85, 0.7, 0.6), 0.25)
	if dist <= slam_radius:
		player.take_damage(attack_damage, global_position)


func _make_warning_disc(color: Color, height: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.mesh = Effects.instance.disc_mesh
	disc.material_override = Effects.instance.material(color)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = height
	disc.visible = false
	add_child(disc)
	return disc
