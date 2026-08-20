extends Node3D

var player: Node3D
var camera: Camera3D
var world_items: Array[Node3D] = []
var state := "menu"
var speed := 0.0
var distance := 0.0
var lane := 0.0
var drag_x := 0.0
var charging := false
var power := 25.0
var power_dir := 1.0
var run_coins := 0
var coins := 100
var best := 0
var launch_level := 1
var boat_level := 1
var income_level := 1
var far_z := -100.0
var hud: Control
var menu: Control
var speed_label: Label
var distance_label: Label
var coin_label: Label
var best_label: Label
var charge_bar: ProgressBar
var hint_label: Label
var result_label: Label
var rng := RandomNumberGenerator.new()

func mat(color: Color, rough := 0.75, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m

func mesh_node(mesh: Mesh, color: Color, pos: Vector3, scale_v := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat(color)
	n.position = pos
	n.scale = scale_v
	return n

func box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new(); m.size = size
	return mesh_node(m, color, pos)

func sphere(radius: float, color: Color, pos: Vector3, scale_v := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new(); m.radius = radius; m.height = radius * 2.0; m.radial_segments = 12; m.rings = 6
	return mesh_node(m, color, pos, scale_v)

func cylinder(radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new(); m.top_radius = radius; m.bottom_radius = radius; m.height = height; m.radial_segments = 16
	return mesh_node(m, color, pos)

func _ready() -> void:
	rng.randomize()
	build_environment()
	build_player()
	build_world_pool()
	build_ui()
	load_save()
	update_menu()

func build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("63cef0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("d9f8ff")
	e.ambient_light_energy = 1.2
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48,-28,0); sun.light_energy = 1.15; sun.shadow_enabled = true; add_child(sun)
	var water_mesh := PlaneMesh.new(); water_mesh.size = Vector2(90,2200); water_mesh.subdivide_width = 20; water_mesh.subdivide_depth = 200
	var water := mesh_node(water_mesh, Color("079fc9"), Vector3(0,0,-1000)); water.material_override = mat(Color("079fc9"),0.18,0.05); add_child(water)
	for side in [-1,1]:
		for i in range(9):
			var island := Node3D.new(); island.position = Vector3(side*(15+rng.randf_range(0,8)),0.1,-60-i*150-rng.randf_range(0,80)); add_child(island)
			island.add_child(sphere(4.0,Color("edcf79"),Vector3.ZERO,Vector3(2.1,.35,1.5)))
			island.add_child(sphere(3.7,Color("36a85c"),Vector3(0,.45,0),Vector3(1.9,.22,1.3)))
			for p in range(2):
				var palm := Node3D.new(); palm.position=Vector3(p*3-1.5,.7,p*1.2); island.add_child(palm)
				palm.add_child(cylinder(.22,4.5,Color("7d502c"),Vector3(0,2.1,0)))
				for a in range(5):
					var leaf:=box(Vector3(.32,.12,3.4),Color("208c49"),Vector3(0,4.3,0)); leaf.rotation_degrees.y=a*72; leaf.position += Vector3(sin(deg_to_rad(a*72))*1.3,0,cos(deg_to_rad(a*72))*1.3); palm.add_child(leaf)
	camera = Camera3D.new(); camera.position=Vector3(0,6.2,10.5); camera.fov=62; add_child(camera); camera.look_at_from_position(camera.position,Vector3(0,1,-15))

func build_player() -> void:
	player=Node3D.new(); player.position=Vector3(0,.55,0); add_child(player)
	var ring_mesh:=TorusMesh.new(); ring_mesh.inner_radius=.65; ring_mesh.outer_radius=1.6; ring_mesh.rings=20; ring_mesh.ring_segments=12
	player.add_child(mesh_node(ring_mesh,Color("ef3845"),Vector3.ZERO,Vector3(1.2,.65,1.35)))
	player.add_child(sphere(.63,Color("ffd438"),Vector3(0,.02,0),Vector3(1,.25,1)))
	player.add_child(cylinder(.34,1.35,Color("1c506b"),Vector3(0,1.05,0)))
	player.add_child(sphere(.36,Color("e5a072"),Vector3(0,1.92,0)))
	player.add_child(sphere(.37,Color("273841"),Vector3(0,2.08,-.03),Vector3(1,.45,1)))
	var wake:=sphere(1.0,Color(1,1,1,.65),Vector3(0,-.25,1.7),Vector3(1.4,.08,2.8)); player.add_child(wake)

func build_world_pool() -> void:
	for i in range(65):
		var item:=Node3D.new(); item.set_meta("kind",choose_kind()); add_child(item); build_item_mesh(item); respawn(item,true); world_items.append(item)

func choose_kind() -> String:
	var r:=rng.randf(); return "coin" if r<.48 else ("ramp" if r<.64 else ("buoy" if r<.82 else "rock"))

func build_item_mesh(item:Node3D) -> void:
	var k:String=item.get_meta("kind")
	if k=="coin":
		var coin:=cylinder(.48,.16,Color("ffd21f"),Vector3(0,1.1,0)); coin.rotation_degrees.x=90; item.add_child(coin)
		item.add_child(sphere(.58,Color("fff18b"),Vector3(0,1.1,.06),Vector3(1,.08,1)))
	elif k=="ramp":
		var ramp:=box(Vector3(3.2,.35,3.8),Color("ff772f"),Vector3(0,.28,0)); ramp.rotation_degrees.x=-12; item.add_child(ramp)
		item.add_child(box(Vector3(.35,.08,3.9),Color.WHITE,Vector3(0,.5,0)))
	elif k=="buoy":
		item.add_child(cylinder(.28,1.8,Color.WHITE,Vector3(0,.9,0))); item.add_child(sphere(.52,Color("ef3543"),Vector3(0,1.65,0)))
	else:
		item.add_child(sphere(1.25,Color("566a72"),Vector3(0,.55,0),Vector3(1.25,.55,1)))

func respawn(item:Node3D, initial:=false) -> void:
	far_z -= rng.randf_range(14,25)
	item.position=Vector3(rng.randf_range(-6.2,6.2),0,far_z if not initial else rng.randf_range(-45,-1150))
	item.visible=true

func style_box(color:Color,radius:=18) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new(); s.bg_color=color; s.corner_radius_top_left=radius; s.corner_radius_top_right=radius; s.corner_radius_bottom_left=radius; s.corner_radius_bottom_right=radius; s.border_width_left=2;s.border_width_right=2;s.border_width_top=2;s.border_width_bottom=2;s.border_color=Color(1,1,1,.55);return s

func label(text:String,size:int) -> Label:
	var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",Color.WHITE);l.add_theme_color_override("font_shadow_color",Color("14506b"));l.add_theme_constant_override("shadow_offset_x",2);l.add_theme_constant_override("shadow_offset_y",2);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;return l

func button(text:String) -> Button:
	var b:=Button.new();b.text=text;b.custom_minimum_size=Vector2(150,62);b.add_theme_font_size_override("font_size",23);b.add_theme_stylebox_override("normal",style_box(Color("ffc930")));b.add_theme_stylebox_override("pressed",style_box(Color("e99a1b")));b.add_theme_color_override("font_color",Color("174d67"));return b

func build_ui() -> void:
	var layer:=CanvasLayer.new();add_child(layer)
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(menu)
	var shade:=ColorRect.new();shade.color=Color(0.02,.25,.34,.22);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(shade)
	var title:=label("AQUA\nRUSH 3D",48);title.position=Vector2(0,80);title.size=Vector2(540,120);menu.add_child(title)
	var lvl:=label("LEVEL 1",20);lvl.name="Level";lvl.position=Vector2(185,205);lvl.size=Vector2(170,40);lvl.add_theme_stylebox_override("normal",style_box(Color("f05261"),14));menu.add_child(lvl)
	var play:=button("OYNA");play.position=Vector2(195,515);play.pressed.connect(start_charge);menu.add_child(play)
	result_label=label("",18);result_label.position=Vector2(0,590);result_label.size=Vector2(540,32);menu.add_child(result_label)
	var names=["FIRLATICI","BOT","KAZANÇ"]
	for i in range(3):
		var panel:=VBoxContainer.new();panel.position=Vector2(10+i*177,700);panel.size=Vector2(167,190);panel.add_theme_stylebox_override("panel",style_box(Color("f7fcff")));menu.add_child(panel)
		var icon:=label(["🚀","🛟","💰"][i],34);panel.add_child(icon)
		var nm:=label(names[i],17);nm.add_theme_color_override("font_color",Color("174d67"));panel.add_child(nm)
		var up:=button("🪙 30");up.name="Upgrade%d"%i;up.custom_minimum_size=Vector2(150,45);up.add_theme_font_size_override("font_size",16);up.pressed.connect(upgrade.bind(i));panel.add_child(up)
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.visible=false;layer.add_child(hud)
	coin_label=label("🪙 0",18);coin_label.position=Vector2(12,20);coin_label.size=Vector2(110,40);coin_label.add_theme_stylebox_override("normal",style_box(Color("164d66"),16));hud.add_child(coin_label)
	best_label=label("🏆 0 m",18);best_label.position=Vector2(408,20);best_label.size=Vector2(120,40);best_label.add_theme_stylebox_override("normal",style_box(Color("164d66"),16));hud.add_child(best_label)
	speed_label=label("0 km/h",34);speed_label.position=Vector2(0,68);speed_label.size=Vector2(540,45);hud.add_child(speed_label)
	distance_label=label("0 m",19);distance_label.position=Vector2(0,112);distance_label.size=Vector2(540,30);hud.add_child(distance_label)
	hint_label=label("BASILI TUT • GÜCÜ AYARLA • BIRAK",17);hint_label.position=Vector2(0,875);hint_label.size=Vector2(540,35);hud.add_child(hint_label)
	charge_bar=ProgressBar.new();charge_bar.position=Vector2(100,835);charge_bar.size=Vector2(340,25);charge_bar.max_value=100;charge_bar.show_percentage=false;charge_bar.add_theme_stylebox_override("background",style_box(Color("174d67"),12));charge_bar.add_theme_stylebox_override("fill",style_box(Color("ffb52f"),12));hud.add_child(charge_bar)

func start_charge()->void:
	menu.visible=false;hud.visible=true;state="charge";power=20;charging=false;speed=0;distance=0;run_coins=0;lane=0;player.position.x=0;far_z=-100
	for it in world_items: respawn(it,true)

func upgrade(which:int)->void:
	var levels=[launch_level,boat_level,income_level];var cost:=30*levels[which]*levels[which]
	if coins<cost:result_label.text="Yeterli altının yok!";return
	coins-=cost
	if which==0:launch_level+=1
	elif which==1:boat_level+=1
	else:income_level+=1
	save_game();update_menu()

func _input(event:InputEvent)->void:
	if event is InputEventScreenTouch:
		if state=="charge":
			if event.pressed:charging=true
			elif charging: launch()
		elif state=="ride":
			drag_x=event.position.x
	elif event is InputEventScreenDrag and state=="ride":
		lane=clamp(lane+event.relative.x*.018,-6.0,6.0)
	if event is InputEventMouseButton:
		if state=="charge" and event.pressed:charging=true
		elif state=="charge" and not event.pressed and charging:launch()
	if event is InputEventMouseMotion and state=="ride" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):lane=clamp(lane+event.relative.x*.018,-6.0,6.0)

func launch()->void:
	state="ride";charging=false;speed=22.0+power*.36+launch_level*2.2;charge_bar.visible=false;hint_label.text="SAĞA • SOLA SÜRÜKLE"

func _process(delta:float)->void:
	if state=="charge":
		if charging:
			power+=power_dir*75.0*delta
			if power>=100:power=100;power_dir=-1
			if power<=10:power=10;power_dir=1
		charge_bar.value=power
	elif state=="ride":
		distance+=speed*delta
		speed=max(0.0,speed-delta*(1.25/(1.0+boat_level*.11)))
		player.position.x=lerp(player.position.x,lane,delta*7.0)
		player.rotation.z=lerp(player.rotation.z,-lane*.035,delta*5.0)
		player.position.y=.55+sin(Time.get_ticks_msec()*.008)*.07
		for item in world_items:
			item.position.z+=speed*delta
			if item.get_meta("kind")=="coin":item.rotation.y+=delta*3
			if item.position.z>5:respawn(item)
			elif abs(item.position.z)<2.0 and abs(item.position.x-player.position.x)<1.35 and item.visible:hit_item(item)
		speed_label.text="%d km/h"%int(speed*3.6);distance_label.text="%d m"%int(distance);coin_label.text="🪙 %d"%(coins+run_coins);best_label.text="🏆 %d m"%best
		if speed<1.0:finish_run()

func hit_item(item:Node3D)->void:
	item.visible=false;var k:String=item.get_meta("kind")
	if k=="coin":run_coins+=income_level
	elif k=="ramp":speed+=10;player.position.y+=.7
	else:speed*=.62

func finish_run()->void:
	state="menu";coins+=run_coins;best=max(best,int(distance));save_game();update_menu();result_label.text="%d m gittin • +%d altın"%[int(distance),run_coins];hud.visible=false;menu.visible=true;charge_bar.visible=true;hint_label.text="BASILI TUT • GÜCÜ AYARLA • BIRAK"

func save_game()->void:
	var f:=FileAccess.open("user://save.json",FileAccess.WRITE);f.store_string(JSON.stringify({"coins":coins,"best":best,"launch":launch_level,"boat":boat_level,"income":income_level}))

func load_save()->void:
	if FileAccess.file_exists("user://save.json"):
		var d=JSON.parse_string(FileAccess.get_file_as_string("user://save.json"));if d is Dictionary:coins=d.get("coins",100);best=d.get("best",0);launch_level=d.get("launch",1);boat_level=d.get("boat",1);income_level=d.get("income",1)

func update_menu()->void:
	coin_label.text="🪙 %d"%coins if coin_label else ""
	if best_label:best_label.text="🏆 %d m"%best
	var levels=[launch_level,boat_level,income_level]
	for i in range(3):
		var b=menu.get_node("Upgrade%d"%i) if menu.has_node("Upgrade%d"%i) else null
		if b:b.text="Seviye %d  •  🪙 %d"%[levels[i],30*levels[i]*levels[i]]
