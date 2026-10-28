extends Node3D

const Adapter = preload("res://addons/gua/gua_auto_adapter.gd")
const SAVE_PATH := "user://checkpoint.json"
const BUG_IDS := ["lost_key", "through_wall", "door_jam"]
var adapter = Adapter.new()
var player: CharacterBody3D
var camera: Camera3D
var capsule: CapsuleShape3D
var world: Node3D
var ui: Control
var panel: VBoxContainer
var hud: VBoxContainer
var status: Label
var prompt: Label
var notice: Label
var controls: HFlowContainer
var items: Dictionary = {}
var door: StaticBody3D
var lift: StaticBody3D
var screen := "title"
var language := "ja"
var inventory: Array = []
var collected: Array = []
var generator := false
var auxiliary := false
var door_open := false
var door_timer := 0.0
var lift_y := 0.0
var lift_target := 0.0
var jammed := false
var crouching := false
var bugs: Array = []
var message := ""
var move_vector := Vector2.ZERO
var move_remaining := 0.0
var seed_value := 3001
var elapsed := 0.0
var run_number := 0
var window_dimensions := Vector2i(1280,800)
var events: Array = []

func tr2(ja: String, en: String) -> String:
	return ja if language == "ja" else en

func _ready() -> void:
	_build_world()
	_build_ui()
	adapter.attach(ui)
	var port := int(OS.get_environment("GUA_BRIDGE_PORT"))
	if port == 0: port = 18732
	if not adapter.start_inspector_bridge(port): push_error("Gua bridge unavailable")
	_show_menu()

func box(pos: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	world.add_child(body)
	body.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.material_override = material
	body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = size
		collision.shape = cube
		body.add_child(collision)
	return body

func sign_at(text: String, pos: Vector3, color := Color("78e5dc")) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 60
	label.pixel_size = 0.008
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	world.add_child(label)

func _build_world() -> void:
	world = Node3D.new()
	add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101b2c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9ac0d1")
	env.ambient_light_energy = 0.8
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65, -25, 0)
	light.light_energy = 1.0
	world.add_child(light)
	box(Vector3(0,-0.25,-6),Vector3(24,0.5,36),Color("253b4b"))
	for x in [-12.0,12.0]: box(Vector3(x,2,-6),Vector3(0.4,4,36),Color("385267"))
	for z in [-24.0,12.0]: box(Vector3(0,2,z),Vector3(24,4,0.4),Color("385267"))
	# Reception/storage/machine-room partitions; the central opening is four metres wide.
	for x in [-7.0,7.0]: box(Vector3(x,1.7,0),Vector3(10,3.4,0.3),Color("45647a"))
	box(Vector3(0,1.7,-8),Vector3(0.3,3.4,8),Color("45647a"))
	# Exit bulkhead and real sliding door.
	box(Vector3(-4.5,1.7,-12),Vector3(15,3.4,0.3),Color("45647a"))
	box(Vector3(10.5,1.7,-12),Vector3(3,3.4,0.3),Color("45647a"))
	door = box(Vector3(6,1.5,-12),Vector3(6,3,0.35),Color("a66538")) as StaticBody3D
	# Glass deliberately collides with interaction rays and the player.
	box(Vector3(-6,1.3,-5),Vector3(4,2.6,0.15),Color(0.3,0.65,0.8,1))
	box(Vector3(6,1.3,-5.8),Vector3(2,2.6,0.15),Color("487d95"))
	sign_at("GLASS / WALK AROUND",Vector3(-6,2.9,-5))
	# Narrow crawl passage with a low roof; no invisible interaction exception.
	box(Vector3(-10,0.7,4),Vector3(0.25,1.4,6),Color("526779"))
	box(Vector3(-11,1.65,4),Vector3(2,0.3,6),Color("526779"))
	# Stairs and ramp lead to a one metre observation ledge.
	for i in range(5): box(Vector3(-5,0.1+0.1*i,-18-i*0.6),Vector3(3,0.2+0.2*i,0.6),Color("607e89"))
	var ramp := box(Vector3(-9,0.5,-19),Vector3(2,0.25,5),Color("607e89"))
	ramp.rotation_degrees.x = -12
	box(Vector3(-7,0.9,-22),Vector3(8,0.2,3),Color("607e89"))
	# Upper exit deck is reachable by the powered elevator.
	box(Vector3(7,2.8,-22),Vector3(9,0.4,4),Color("45647a"))
	lift = box(Vector3(8,-0.15,-18),Vector3(3,0.3,4),Color("65b5ac")) as StaticBody3D
	sign_at("01  RECEPTION",Vector3(0,3,8))
	sign_at("02  STORAGE",Vector3(-6,3,-2))
	sign_at("03  MACHINE",Vector3(6,3,-4))
	sign_at("04  EXIT / LIFT",Vector3(6,4.5,-20))
	add_item("tool",Vector3(-3,1,5),Color("ffc56e"),"TOOL")
	add_item("battery",Vector3(3,1,5),Color("7ce4b0"),"BATTERY")
	add_item("key",Vector3(-8,1,-2),Color("e9cb65"),"CARD KEY")
	add_item("generator",Vector3(6,1,-7),Color("ed9c6a"),"A / BATTERY")
	add_item("auxiliary",Vector3(-6,1,-8),Color("78cbdc"),"B / TOOL")
	add_item("door",Vector3(4,1,-10),Color("ed9c6a"),"DOOR / CARD")
	add_item("lift",Vector3(8,0.6,-18),Color("78cbdc"),"LIFT / POWER")
	add_item("exit",Vector3(8,4.1,-22),Color("7ce4b0"),"EXIT")
	player = CharacterBody3D.new()
	player.floor_snap_length = 0.3
	player.safe_margin = 0.03
	world.add_child(player)
	var collision := CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	player.add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.45
	camera.fov = 78
	player.add_child(camera)
	player.position = Vector3(0,0.1,8)

func add_item(id: String, pos: Vector3, color: Color, caption: String) -> void:
	var body := box(pos,Vector3(0.65,0.65,0.65),color)
	body.set_meta("item_id",id)
	items[id] = body
	sign_at(caption,pos+Vector3(0,0.7,0),color)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	var theme := Theme.new()
	theme.default_font_size = 19
	ui.theme = theme
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	hud = VBoxContainer.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hud)
	status = label("status", "")
	hud.add_child(status)
	prompt = label("target", "")
	hud.add_child(prompt)
	notice = label("notice", "")
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(notice)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	panel = VBoxContainer.new()
	column.add_child(panel)
	controls = HFlowContainer.new()
	column.add_child(controls)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(cross)

func label(id: String, text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.set_meta("gua_id",id)
	return node

func button(parent: Node, id: String, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.set_meta("gua_id",id)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _show_menu() -> void:
	clear_children(panel)
	clear_children(controls)
	hud.visible = false
	panel.add_child(label("heading",tr2("FACILITY 03 / 故障した施設からの脱出","FACILITY 03 / ESCAPE THE BLACKOUT")))
	panel.add_child(label("instructions",tr2("WASD 移動・矢印/右ドラッグ 視点・E 操作・C しゃがむ・Esc 中断\n電池をAへ、工具でBを復旧。カードで扉を開け、リフトで出口へ。","WASD move / arrows or right-drag look / E interact / C crouch / Esc pause\nBattery powers A. Tool repairs B. Card opens bulkhead. Ride lift to exit.")))
	if screen == "title" or screen == "result":
		button(panel,"start",tr2("新しく開始 / 再プレイ","New run / Replay"),new_run)
	else:
		button(panel,"resume",tr2("続ける","Resume"),resume_game)
		button(panel,"save",tr2("チェックポイント保存","Save checkpoint"),save_game)
	button(panel,"load",tr2("チェックポイントから再開","Load checkpoint"),load_game)
	button(panel,"language",tr2("Language: 日本語 → English","Language: English → 日本語"),func(): language = "en" if language == "ja" else "ja"; _show_menu())
	button(panel,"resize",tr2("画面サイズ 1280 / 960","Window size 1280 / 960"),resize_window)
	button(panel,"reset",tr2("初期状態にリセット（セーブは保持）","Reset to initial state (keep checkpoint)"),new_run)
	var bug_row := HBoxContainer.new()
	panel.add_child(bug_row)
	for id in BUG_IDS:
		var bug_id: String = id
		button(bug_row,"bug_"+id,("[ON] " if bugs.has(id) else "[off] ")+id,func(): toggle_bug(bug_id))
	panel.add_child(label("run_info","scenario=facility-r1 | seed=%d | bugs=%s | run=%d" % [seed_value,str(bugs),run_number]))
	if screen == "result": panel.add_child(label("result",tr2("脱出成功！通常の移動と装置操作で出口に到達しました。","ESCAPED! You reached the exit through movement and device interactions.")))
	panel.add_child(label("menu_message",message))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _show_play_ui() -> void:
	clear_children(panel)
	clear_children(controls)
	hud.visible = true
	for spec in [["forward","↑",Vector2(0,-1)],["back","↓",Vector2(0,1)],["left","←",Vector2(-1,0)],["right","→",Vector2(1,0)]]:
		var vector: Vector2 = spec[2]
		button(controls,spec[0],spec[1],func(): walk_pulse(vector))
	button(controls,"turn_left","↶ 15°",func(): turn(-15))
	button(controls,"turn_right","↷ 15°",func(): turn(15))
	button(controls,"look_up","View ↑",func(): look(-10))
	button(controls,"look_down","View ↓",func(): look(10))
	button(controls,"interact",tr2("E 操作","E Use"),interact)
	button(controls,"crouch",tr2("C しゃがむ","C Crouch"),toggle_crouch)
	button(controls,"pause",tr2("Esc 中断","Esc Pause"),pause_game)

func new_run() -> void:
	inventory = []
	collected = []
	generator = false
	auxiliary = false
	door_open = false
	door_timer = 0
	lift_y = 0
	lift_target = 0
	jammed = false
	crouching = false
	move_remaining = 0
	elapsed = 0
	run_number += 1
	player.position = Vector3(0,0.1,8)
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	screen = "play"
	message = tr2("電池・工具・カードを探してください。操作距離は 2.3m。","Find battery, tool and card. Interaction range is 2.3m.")
	_sync_world()
	_show_play_ui()
	record_event("new_run")

func pause_game() -> void:
	if screen != "play": return
	screen = "pause"
	move_remaining = 0
	move_vector = Vector2.ZERO
	_show_menu()
	record_event("pause")

func resume_game() -> void:
	screen = "play"
	_show_play_ui()
	record_event("resume")

func resize_window() -> void:
	window_dimensions = Vector2i(960,720) if window_dimensions.x > 1000 else Vector2i(1280,800)
	get_window().size = window_dimensions
	record_event("resize")

func toggle_bug(id: String) -> void:
	if bugs.has(id): bugs.erase(id)
	else: bugs.append(id)
	_show_menu()
	record_event("bug_toggle:"+id)

func walk_pulse(vector: Vector2) -> void:
	if screen != "play": return
	move_vector = vector
	move_remaining = 0.25
	record_event("walk:"+str(vector))

func turn(degrees: float) -> void:
	if screen == "play": player.rotation_degrees.y -= degrees

func look(degrees: float) -> void:
	if screen == "play": camera.rotation_degrees.x = clampf(camera.rotation_degrees.x-degrees,-65,65)

func toggle_crouch() -> void:
	if screen != "play": return
	if crouching:
		var query := PhysicsRayQueryParameters3D.create(player.position+Vector3(0,0.5,0),player.position+Vector3(0,1.8,0))
		query.exclude = [player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			message = tr2("天井が低いため立てません。","Ceiling too low to stand.")
			return
	crouching = not crouching
	capsule.height = 1.0 if crouching else 1.7
	player.get_child(0).position.y = capsule.height/2.0
	camera.position.y = 0.8 if crouching else 1.45
	record_event("crouch")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if screen == "play": pause_game()
				elif screen == "pause": resume_game()
			KEY_E: interact()
			KEY_C: toggle_crouch()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and screen == "play":
		player.rotation.y -= event.relative.x*0.003
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*0.003,-1.13,1.13)

func _physics_process(delta: float) -> void:
	if screen != "play": return
	elapsed += delta
	var old_lift := lift_y
	lift_y = move_toward(lift_y,lift_target,delta)
	if absf(player.position.x-8)<1.5 and absf(player.position.z+18)<2 and absf(player.position.y-old_lift)<0.4:
		player.position.y += lift_y-old_lift
	lift.position.y = lift_y-0.15
	items.lift.position.y = lift_y+0.6
	var direction := Vector2.ZERO
	if move_remaining > 0:
		direction = move_vector
		move_remaining -= delta
	if Input.is_physical_key_pressed(KEY_W): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S): direction.y += 1
	if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D): direction.x += 1
	if Input.is_physical_key_pressed(KEY_LEFT): turn(-90*delta)
	if Input.is_physical_key_pressed(KEY_RIGHT): turn(90*delta)
	if Input.is_physical_key_pressed(KEY_UP): look(-60*delta)
	if Input.is_physical_key_pressed(KEY_DOWN): look(60*delta)
	var motion := player.basis * Vector3(direction.x,0,direction.y).normalized()
	player.velocity.x = motion.x*(1.8 if crouching else 3.0) if not jammed else 0.0
	player.velocity.z = motion.z*(1.8 if crouching else 3.0) if not jammed else 0.0
	if not player.is_on_floor(): player.velocity.y -= 18*delta
	else: player.velocity.y = 0
	player.move_and_slide()
	# Small steps use a physical clearance test, keeping walls and roofs solid.
	if player.is_on_wall() and direction.length()>0 and player.is_on_floor() and not jammed:
		var rise := Vector3(0,0.22,0)
		if not player.test_move(player.transform,rise) and not player.test_move(player.transform.translated(rise),motion*0.12):
			player.position += rise
	if door_open:
		door_timer -= delta
		if door_timer <= 0:
			var occupied := absf(player.position.z+12)<1.0 and player.position.x>2.6 and player.position.x<9.4
			if occupied and bugs.has("door_jam"):
				jammed = true
				door_open = false
				message = "BUG door_jam: reset or load checkpoint to recover"
			elif not occupied: door_open = false
			else: door_timer = 0.25
			door.position.y = 5.0 if door_open else 1.5
	if player.position.y < -4:
		player.position = Vector3(0,0.1,8)
		player.velocity = Vector3.ZERO
		message = tr2("受付へ安全復帰しました。","Returned safely to reception.")

func target_id(ignore_walls := false) -> String:
	var origin := camera.global_position
	var end := origin-camera.global_basis.z*2.3
	var query := PhysicsRayQueryParameters3D.create(origin,end)
	query.exclude = [player.get_rid()]
	if ignore_walls:
		# Known defect: skips blockers but still respects distance and aim.
		var exclusions: Array[RID] = [player.get_rid()]
		for i in range(16):
			query.exclude = exclusions
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): return ""
			if hit.collider.has_meta("item_id"): return str(hit.collider.get_meta("item_id"))
			exclusions.append(hit.collider.get_rid())
		return ""
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return str(hit.collider.get_meta("item_id","")) if not hit.is_empty() else ""

func interact() -> void:
	if screen != "play": return
	var id := target_id(bugs.has("through_wall"))
	if id.is_empty():
		message = tr2("対象を中央に合わせ、近づいてください。壁やガラス越しには操作できません。","Aim at a nearby object. Walls and glass block interaction.")
		record_event("interact:none")
		return
	match id:
		"tool","battery","key":
			if not collected.has(id):
				inventory.append(id)
				collected.append(id)
				message = tr2("取得: ","Picked up: ")+id
		"generator":
			if generator: message = tr2("A は稼働中です。","A is already online.")
			elif inventory.has("battery"):
				inventory.erase("battery")
				generator = true
				message = tr2("A 復旧。電池を消費しました。","A online. Battery consumed.")
			else: message = tr2("電池が必要です。","Battery required.")
		"auxiliary":
			if inventory.has("tool"):
				auxiliary = true
				message = tr2("B 復旧。工具は保持されます。","B repaired. Tool retained.")
			else: message = tr2("工具が必要です。","Tool required.")
		"door":
			if generator and inventory.has("key"):
				door_open = true
				door_timer = 4
				message = tr2("扉を4秒間開きます。通行中は閉まりません。","Door open for 4s; occupancy prevents closing.")
			else: message = tr2("A の電源とカードキーが必要です。","A power and card key required.")
		"lift":
			if generator and auxiliary:
				lift_target = 3.0 if lift_target < 1 else 0.0
				message = tr2("リフト移動開始。搭乗したまま中断・保存できます。","Lift moving. Pause/save while aboard is supported.")
			else: message = tr2("A と B 両方の復旧が必要です。","Both A and B must be online.")
		"exit":
			if generator and auxiliary and inventory.has("key"):
				screen = "result"
				message = "ESCAPED | scenario=facility-r1 | seed=%d | bugs=%s | time=%.2f" % [seed_value,str(bugs),elapsed]
				_show_menu()
			else: message = tr2("電源 A/B とカードキーを確認してください。","Check A/B power and card key.")
	_sync_world()
	record_event("interact:"+id)

func _sync_world() -> void:
	for id in ["key","battery","tool"]:
		items[id].visible = not collected.has(id)
		items[id].get_child(1).set_deferred("disabled",collected.has(id))
	door.position.y = 5.0 if door_open else 1.5
	lift.position.y = lift_y-0.15
	items.lift.position.y = lift_y+0.6
	capsule.height = 1.0 if crouching else 1.7
	player.get_child(0).position.y = capsule.height/2
	camera.position.y = 0.8 if crouching else 1.45

func snapshot() -> Dictionary:
	if DisplayServer.get_name() != "headless" and get_window().size.x >= 640:
		window_dimensions = get_window().size
	return {"schema":1,"scenario":"facility-r1","seed":seed_value,"bugs":bugs.duplicate(),"inventory":inventory.duplicate(),"collected":collected.duplicate(),"generator":generator,"auxiliary":auxiliary,"door_open":door_open,"door_timer":door_timer,"lift_y":lift_y,"lift_target":lift_target,"jammed":jammed,"crouching":crouching,"position":[player.position.x,player.position.y,player.position.z],"yaw":player.rotation.y,"pitch":camera.rotation.x,"language":language,"window":[window_dimensions.x,window_dimensions.y],"elapsed":elapsed,"run":run_number}

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if file == null:
		message = "Save failed: "+str(FileAccess.get_open_error())
		_show_menu()
		return
	file.store_string(JSON.stringify(snapshot(),"\t"))
	file.close()
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH+".tmp"),ProjectSettings.globalize_path(SAVE_PATH))
	message = tr2("チェックポイント保存完了。","Checkpoint saved.") if result == OK else "Save rename failed: "+str(result)
	record_event("save")
	_show_menu()

func load_game() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)) if FileAccess.file_exists(SAVE_PATH) else null
	if not valid_save(data):
		message = tr2("有効なチェックポイントがありません。現在の状態は保持しました。","No valid checkpoint. Current state retained.")
		_show_menu()
		return
	inventory = data.inventory.duplicate()
	collected = data.collected.duplicate()
	bugs = data.bugs.duplicate()
	if bugs.has("lost_key"): inventory.erase("key")
	generator = data.generator
	auxiliary = data.auxiliary
	door_open = data.door_open
	door_timer = data.door_timer
	lift_y = data.lift_y
	lift_target = data.lift_target
	jammed = data.jammed
	crouching = data.crouching
	player.position = Vector3(data.position[0],data.position[1],data.position[2])
	player.rotation.y = data.yaw
	camera.rotation.x = data.pitch
	player.velocity = Vector3.ZERO
	language = data.language
	elapsed = data.elapsed
	seed_value = data.seed
	run_number = data.run
	window_dimensions = Vector2i(data.window[0],data.window[1])
	get_window().size = window_dimensions
	move_remaining = 0
	message = tr2("チェックポイントから復帰しました。","Checkpoint restored.")
	_sync_world()
	resume_game()
	record_event("load")

func valid_save(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key in snapshot().keys():
		if not data.has(key): return false
	if data.schema != 1 or data.scenario != "facility-r1": return false
	if not data.inventory is Array or not data.collected is Array or not data.bugs is Array: return false
	if not data.position is Array or data.position.size()!=3 or not data.window is Array or data.window.size()!=2: return false
	for n in data.position+data.window+[data.yaw,data.pitch,data.door_timer,data.lift_y,data.lift_target,data.elapsed,data.seed,data.run]:
		if not (n is float or n is int) or not is_finite(float(n)): return false
	for key in ["generator","auxiliary","door_open","jammed","crouching"]:
		if not data[key] is bool: return false
	if data.language not in ["ja","en"]: return false
	for id in data.inventory+data.collected:
		if id not in ["key","battery","tool"]: return false
	for id in data.bugs:
		if id not in BUG_IDS: return false
	return absf(data.position[0])<12 and data.position[2]>-24 and data.position[2]<12 and data.position[1]>=-0.5 and data.position[1]<6 and data.lift_y>=0 and data.lift_y<=3 and (data.lift_target == 0.0 or data.lift_target == 3.0) and data.window[0]>=640 and data.window[0]<=3840 and data.window[1]>=480 and data.window[1]<=2160

func record_event(action: String) -> void:
	events.append({"action":action,"time":elapsed,"screen":screen,"state":snapshot()})
	if events.size()>2000: events.pop_front()
	var file := FileAccess.open("user://last-run.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"build":"0.1.0","gua":"1.1.2","events":events},"\t"))

func _process(_delta: float) -> void:
	if screen == "play":
		status.text = "FACILITY 03 | A:%s B:%s | %s=%s | %s | %.1fs" % [str(generator),str(auxiliary),tr2("所持","Bag"),str(inventory),"CROUCH" if crouching else "STAND",elapsed]
		var target := target_id(bugs.has("through_wall"))
		prompt.text = (tr2("対象: ","Target: ")+target if not target.is_empty() else tr2("対象なし / 中央 + を近くの物へ","No target / aim + at a nearby object"))+" | xyz=(%.2f,%.2f,%.2f) yaw=%.1f pitch=%.1f" % [player.position.x,player.position.y,player.position.z,player.rotation_degrees.y,camera.rotation_degrees.x]
		notice.text = message+" | bugs="+str(bugs)
	adapter.update(screen)

func _exit_tree() -> void:
	if adapter: adapter.dispose()
