extends CanvasLayer
## 체력 바, 스킬 쿨다운 3칸, 웨이브 표시, 웨이브 안내, 피격 비네트, 결과 화면을 코드로 만든다.
## 게임 상태는 신호로만 듣고, R 키 재시작도 여기서 처리한다.

@export var player_path: NodePath
@export var wave_manager_path: NodePath
@export var banner_time := 1.5
@export var vignette_time := 0.2
@export var defeat_delay := 1.0
@export var victory_delay := 0.6

## [쿨다운 이름, 키, 동작]
const SKILLS := [["melee", "우클릭", "칼"], ["spear", "Q", "창"], ["roll", "Space", "구르기"]]
const SLOT_SIZE := Vector2(64, 52)
const HP_SIZE := Vector2(220, 22)

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5)) * 1.41;
	COLOR = vec4(0.85, 0.0, 0.0, smoothstep(0.45, 1.0, d) * intensity);
}
"""

var _player: Player
var _waves: Node
var _hp_fill: ColorRect
var _hp_label: Label
var _wave_label: Label
var _banner: Label
var _banner_left := 0.0
var _vignette: ShaderMaterial
var _vignette_left := 0.0
var _slots: Array[Dictionary] = []
var _result: Control
var _result_title: Label
var _result_body: Label
var _finished := false
var _last_health := -1.0


func _ready() -> void:
	_player = get_node(player_path)
	_waves = get_node(wave_manager_path)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_vignette(root)
	_build_health(root)
	_build_skills(root)
	_build_wave_info(root)
	_build_result(root)
	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(_on_player_died)
	_waves.wave_started.connect(_on_wave_started)
	_waves.remaining_changed.connect(_on_remaining_changed)
	_waves.all_waves_cleared.connect(_on_all_waves_cleared)
	_on_health_changed(_player.health, _player.max_health)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	for slot in _slots:
		var left: float = _player.cooldowns[slot.skill]
		var ratio := left / _player.cooldown_total(slot.skill)
		slot.shade.size.y = SLOT_SIZE.y * ratio
		slot.time.text = "%.1f" % left if left > 0.0 else ""
		slot.action.visible = left <= 0.0
	if _vignette_left > 0.0:
		_vignette_left -= delta
		_vignette.set_shader_parameter("intensity", maxf(_vignette_left / vignette_time, 0.0))
	if _banner_left > 0.0:
		_banner_left -= delta
		_banner.visible = _banner_left > 0.0


func _on_health_changed(current: float, maximum: float) -> void:
	if _last_health >= 0.0 and current < _last_health:
		_vignette_left = vignette_time
	_last_health = current
	_hp_fill.size.x = HP_SIZE.x * clampf(current / maximum, 0.0, 1.0)
	_hp_label.text = "%d / %d" % [ceili(current), ceili(maximum)]


func _on_wave_started(number: int, total: int) -> void:
	_wave_label.text = "웨이브 %d / %d · 남은 적 %d" % [number, total, _waves.remaining]
	_banner.text = "웨이브 %d" % number
	_banner.visible = true
	_banner_left = banner_time


func _on_remaining_changed(remaining: int) -> void:
	_wave_label.text = "웨이브 %d / %d · 남은 적 %d" % [_waves.current_wave, _waves.waves.size(), remaining]


func _on_player_died() -> void:
	get_tree().create_timer(defeat_delay).timeout.connect(_show_result.bind(false))


func _on_all_waves_cleared() -> void:
	get_tree().create_timer(victory_delay).timeout.connect(_show_result.bind(true))


func _show_result(victory: bool) -> void:
	if _finished:
		return
	_finished = true
	var seconds := int(_waves.elapsed)
	_result_title.text = "승리!" if victory else "쓰러졌다…"
	_result_title.modulate = Color(1.0, 0.85, 0.35) if victory else Color(0.9, 0.35, 0.3)
	_result_body.text = "처치 %d · 시간 %d:%02d\n\nR 키로 다시 시작" % [_waves.kills, seconds / 60, seconds % 60]
	_result.visible = true


# --- UI 만들기 ---

func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "Noto Sans KR", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	theme.set_constant("outline_size", "Label", 4)
	return theme


## anchor 지점을 기준으로 offset 위치에 size 크기로 놓는다.
func _place(ctrl: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	ctrl.anchor_left = anchor.x
	ctrl.anchor_right = anchor.x
	ctrl.anchor_top = anchor.y
	ctrl.anchor_bottom = anchor.y
	ctrl.offset_left = offset.x
	ctrl.offset_top = offset.y
	ctrl.offset_right = offset.x + size.x
	ctrl.offset_bottom = offset.y + size.y


func _rect(parent: Control, color: Color, size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _label(parent: Control, font_size: int, size: Vector2) -> Label:
	var label := Label.new()
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _build_vignette(root: Control) -> void:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette = ShaderMaterial.new()
	_vignette.shader = shader
	rect.material = _vignette
	root.add_child(rect)


func _build_health(root: Control) -> void:
	var box := Control.new()
	_place(box, Vector2(0, 1), Vector2(16, -16 - HP_SIZE.y), HP_SIZE)
	root.add_child(box)
	_rect(box, Color(0.1, 0.08, 0.08, 0.8), HP_SIZE)
	_hp_fill = _rect(box, Color(0.85, 0.15, 0.13), HP_SIZE)
	_hp_label = _label(box, 14, HP_SIZE)


func _build_skills(root: Control) -> void:
	var gap := 8.0
	var total := SLOT_SIZE.x * SKILLS.size() + gap * (SKILLS.size() - 1)
	for i in SKILLS.size():
		var slot := Control.new()
		_place(slot, Vector2(0.5, 1), Vector2(-total * 0.5 + i * (SLOT_SIZE.x + gap), -12 - SLOT_SIZE.y), SLOT_SIZE)
		root.add_child(slot)
		_rect(slot, Color(0.18, 0.15, 0.12, 0.85), SLOT_SIZE)
		var key := _label(slot, 11, Vector2(SLOT_SIZE.x, 18))
		key.text = SKILLS[i][1]
		key.modulate = Color(1, 0.9, 0.6)
		var action := _label(slot, 15, SLOT_SIZE)
		action.position.y = 6
		action.text = SKILLS[i][2]
		var shade := _rect(slot, Color(0, 0, 0, 0.65), Vector2(SLOT_SIZE.x, 0))
		var time := _label(slot, 18, SLOT_SIZE)
		_slots.append({"skill": SKILLS[i][0], "action": action, "shade": shade, "time": time})


func _build_wave_info(root: Control) -> void:
	_wave_label = Label.new()
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 17)
	_place(_wave_label, Vector2(0.5, 0), Vector2(-200, 10), Vector2(400, 26))
	root.add_child(_wave_label)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate = Color(1.0, 0.88, 0.5)
	_banner.visible = false
	_place(_banner, Vector2(0.5, 0.5), Vector2(-200, -110), Vector2(400, 60))
	root.add_child(_banner)


func _build_result(root: Control) -> void:
	var size := Vector2(360, 190)
	_result = Control.new()
	_place(_result, Vector2(0.5, 0.5), -size * 0.5, size)
	_result.visible = false
	root.add_child(_result)
	_rect(_result, Color(0.08, 0.06, 0.05, 0.82), size)
	_result_title = _label(_result, 36, Vector2(size.x, 80))
	_result_title.position.y = 12
	_result_body = _label(_result, 16, Vector2(size.x, 90))
	_result_body.position.y = 88
