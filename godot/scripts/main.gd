extends Node3D

const TRACK_HALF := 7.0
const POOL_SIZE := 84
var rng:=RandomNumberGenerator.new()
var player:Node3D
var camera:Camera3D
var tiles:Array[Node3D]=[]
var scenery:Array[Node3D]=[]
var objects:Array[Node3D]=[]
var menu:Control
var hud:Control
var result:Control
var speed_text:Label
var distance_text:Label
var coins_text:Label
var air_text:Label
var result_text:Label
var progress:ProgressBar
var upgrade_buttons:Array[Button]=[]
var state="menu"
var speed:=0.0
var distance:=0.0
var target_x:=0.0
var y_speed:=0.0
var airborne:=false
var air_time:=0.0
var best_air:=0.0
var immunity:=0.0
var spawn_z:=-35.0
var run_coins:=0
var coins:=350
var gems:=12
var best:=0
var level:=1
var launcher:=1
var sled:=1
var income:=1

func mat(c:Color,emit:=Color.BLACK)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=c;m.roughness=.72
	if emit!=Color.BLACK:m.emission_enabled=true;m.emission=emit;m.emission_energy_multiplier=1.3
	return m
func node(mesh:Mesh,c:Color,p:=Vector3.ZERO,s:=Vector3.ONE)->MeshInstance3D:
	var n:=MeshInstance3D.new();n.mesh=mesh;n.material_override=mat(c);n.position=p;n.scale=s;return n
func box(sz:Vector3,c:Color,p:=Vector3.ZERO)->MeshInstance3D:
	var m:=BoxMesh.new();m.size=sz;return node(m,c,p)
func ball(r:float,c:Color,p:=Vector3.ZERO,s:=Vector3.ONE)->MeshInstance3D:
	var m:=SphereMesh.new();m.radius=r;m.height=r*2;m.radial_segments=12;m.rings=7;return node(m,c,p,s)
func cyl(r:float,h:float,c:Color,p:=Vector3.ZERO)->MeshInstance3D:
	var m:=CylinderMesh.new();m.top_radius=r;m.bottom_radius=r;m.height=h;m.radial_segments=12;return node(m,c,p)

func _ready():
	rng.randomize();build_environment();build_player();build_course();build_pool();build_ui();load_game();show_menu()

func build_environment():
	var we:=WorldEnvironment.new();var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR;e.background_color=Color("99d9f1");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("e3f8ff");e.ambient_light_energy=1.15;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;e.fog_enabled=true;e.fog_light_color=Color("d2edf6");e.fog_density=.005;we.environment=e;add_child(we)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-28,0);sun.light_energy=1.25;sun.shadow_enabled=true;add_child(sun)
	camera=Camera3D.new();camera.position=Vector3(0,5.7,9.5);camera.fov=63;add_child(camera);camera.look_at_from_position(camera.position,Vector3(0,1,-13))

func build_course():
	for i in range(11):
		var t:=Node3D.new();t.position=Vector3(0,-.12,-i*38+10);add_child(t)
		t.add_child(box(Vector3(18,.4,39),Color("edf9ff")))
		for x in [-2.4,2.4]:t.add_child(box(Vector3(.15,.04,38),Color("bee3f1"),Vector3(x,.23,0)))
		tiles.append(t)
	for i in range(72):
		var d:=make_scenery(i);add_child(d);scenery.append(d)

func make_scenery(i:int)->Node3D:
	var d:=Node3D.new();d.set_meta("side",-1 if i%2==0 else 1);d.set_meta("kind",i%5)
	if i%5<3:
		d.add_child(cyl(.25,2.5,Color("694931"),Vector3(0,1.25,0)))
		var cm:=CylinderMesh.new();cm.top_radius=0;cm.bottom_radius=1.45;cm.height=3.2;cm.radial_segments=8;d.add_child(node(cm,Color("278364"),Vector3(0,3,0)))
		d.add_child(ball(.8,Color("f6fcff"),Vector3(0,3.1,0),Vector3(1,.18,1)))
	elif i%5==3:d.add_child(ball(1.8,Color("5d6c77"),Vector3(0,.5,0),Vector3(1.4,.75,1)))
	else:
		d.add_child(cyl(.18,5,Color("5b4534"),Vector3(0,2.5,0)))
		for y in [1.3,2.6,3.9]:d.add_child(box(Vector3(2.7,.3,.3),Color("725238"),Vector3(0,y,0)))
	respawn_scenery(d,true,i);return d
func respawn_scenery(d:Node3D,initial:=false,i:=0):
	var z=-18.0-i*5.5 if initial else -410-rng.randf_range(0,40)
	d.position=Vector3(int(d.get_meta("side"))*rng.randf_range(10,17),0,z);d.rotation_degrees.y=rng.randf_range(-25,25)

func build_player():
	player=Node3D.new();player.position=Vector3(0,.32,0);add_child(player)
	player.add_child(box(Vector3(2.5,.34,3.5),Color("ee4056"),Vector3(0,.18,0)))
	player.add_child(box(Vector3(2.05,.22,2.55),Color("26a9cc"),Vector3(0,.45,-.05)))
	for x in [-.9,.9]:player.add_child(box(Vector3(.16,.18,3.85),Color("403944"),Vector3(x,-.08,.1)))
	for x in [-.42,.42]:
		var leg:=cyl(.2,1.15,Color("244d79"),Vector3(x,.98,.18));leg.rotation_degrees.x=16;player.add_child(leg)
	player.add_child(box(Vector3(1.3,1.55,.75),Color("e74a4c"),Vector3(0,2.05,.05)))
	player.add_child(box(Vector3(1.08,.26,.8),Color("f4f6f8"),Vector3(0,2.2,.05)))
	for x in [-.82,.82]:
		var arm:=cyl(.18,1.25,Color("e74a4c"),Vector3(x,2.05,-.15));arm.rotation_degrees.z=-28*x;player.add_child(arm)
	player.add_child(cyl(.16,2.8,Color("75502d"),Vector3(0,1.5,-.35)));player.add_child(box(Vector3(3,.17,.17),Color("75502d"),Vector3(0,2.85,-.35)))
	player.add_child(ball(.48,Color("e7a176"),Vector3(0,3.14,.02)));player.add_child(ball(.52,Color("203f5b"),Vector3(0,3.38,.02),Vector3(1,.65,1)));player.add_child(box(Vector3(1.15,.18,.85),Color("ffd13d"),Vector3(0,3.47,.02)))
	var scarf:=box(Vector3(.25,.18,1.5),Color("36d3a5"),Vector3(.35,2.72,.6));scarf.rotation_degrees.x=18;player.add_child(scarf)

func build_pool():
	for i in range(POOL_SIZE):
		var o:=Node3D.new();add_child(o);objects.append(o);configure(o,kind_for(i));place(o,true,i)
func kind_for(i:int)->String:
	var n=i%12
	if n<5:return "coin"
	if n<7:return "rock"
	if n==7:return "ramp"
	if n==8:return "gate"
	if n<11:return "post"
	return "boost"
func configure(o:Node3D,k:String):
	o.set_meta("kind",k)
	if k=="coin":
		var c:=cyl(.42,.14,Color("ffca25"),Vector3(0,1,0));c.rotation_degrees.x=90;o.add_child(c);o.add_child(ball(.5,Color("fff1a2"),Vector3(0,1,.07),Vector3(1,.08,1)))
	elif k=="rock":o.add_child(ball(1.15,Color("586975"),Vector3(0,.48,0),Vector3(1.3,.62,1)));o.add_child(ball(.8,Color("f5fcff"),Vector3(0,1,0),Vector3(1.15,.2,1)))
	elif k=="ramp":
		var r:=box(Vector3(3.5,.42,4.2),Color("ff8434"),Vector3(0,.3,0));r.rotation_degrees.x=-13;o.add_child(r);o.add_child(box(Vector3(.34,.07,4),Color.WHITE,Vector3(0,.58,0)))
	elif k=="gate":
		for x in [-2.3,2.3]:o.add_child(cyl(.25,4.4,Color("3e4a54"),Vector3(x,2.2,0)))
		o.add_child(box(Vector3(5.2,.35,.35),Color("765033"),Vector3(0,4.15,0)))
		for x in [-1.7,0,1.7]:o.add_child(cyl(.23,1.5,Color("ffce39"),Vector3(x,3.25,0)))
	elif k=="post":
		o.add_child(cyl(.33,2.7,Color("404d59"),Vector3(0,1.35,0)))
		for y in [1,1.7,2.4]:o.add_child(cyl(.39,.22,Color("edf8fc"),Vector3(0,y,0)))
	else:
		var p:=box(Vector3(3,.12,3.5),Color("25d2eb"),Vector3(0,.12,0));p.material_override=mat(Color("25d2eb"),Color("159fb8"));o.add_child(p)
func place(o:Node3D,initial:=false,i:=0):
	spawn_z=-35.0-i*9.0 if initial else spawn_z-rng.randf_range(8,14)
	var lanes=[-5.2,-2.6,0.0,2.6,5.2];var x:float=lanes[rng.randi_range(0,4)]
	if o.get_meta("kind")=="gate":x=0
	if o.get_meta("kind")=="coin" and i%5!=0:x=lanes[int(i/5)%5]
	o.position=Vector3(x,0,spawn_z);o.visible=true

func style(c:Color,r:=16)->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=c;s.corner_radius_top_left=r;s.corner_radius_top_right=r;s.corner_radius_bottom_left=r;s.corner_radius_bottom_right=r;s.border_width_left=2;s.border_width_top=2;s.border_width_right=2;s.border_width_bottom=2;s.border_color=Color(1,1,1,.5);s.shadow_color=Color(0,0,0,.2);s.shadow_size=4;return s
func label(t:String,z:int,c:=Color.WHITE)->Label:
	var l:=Label.new();l.text=t;l.add_theme_font_size_override("font_size",z);l.add_theme_color_override("font_color",c);l.add_theme_color_override("font_shadow_color",Color(0,.1,.2,.8));l.add_theme_constant_override("shadow_offset_x",2);l.add_theme_constant_override("shadow_offset_y",2);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;return l
func button(t:String,c:=Color("28ace0"))->Button:
	var b:=Button.new();b.text=t;b.custom_minimum_size=Vector2(155,58);b.add_theme_font_size_override("font_size",20);b.add_theme_stylebox_override("normal",style(c));b.add_theme_stylebox_override("pressed",style(c.darkened(.2)));b.add_theme_color_override("font_color",Color.WHITE);return b

func build_ui():
	var layer:=CanvasLayer.new();add_child(layer)
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(menu)
	var cur:=label("🎟 20     🪙 350     💎 12",21);cur.name="Currencies";cur.position=Vector2(8,12);cur.size=Vector2(410,48);cur.add_theme_stylebox_override("normal",style(Color(.05,.2,.3,.72)));menu.add_child(cur)
	var lv:=label("LEVEL 1",28);lv.name="Level";lv.position=Vector2(145,90);lv.size=Vector2(250,50);lv.add_theme_stylebox_override("normal",style(Color("ef5068")));menu.add_child(lv)
	var tasks:=button("GÜNLÜK\nGÖREVLER",Color("7058d7"));tasks.position=Vector2(15,165);tasks.size=Vector2(145,78);tasks.pressed.connect(show_tasks);menu.add_child(tasks)
	var chest:=button("🎁\nSANDIK",Color("e3a327"));chest.position=Vector2(380,165);chest.size=Vector2(145,78);menu.add_child(chest)
	var play:=button("BAŞLA",Color("20bddf"));play.position=Vector2(170,565);play.size=Vector2(200,72);play.add_theme_font_size_override("font_size",28);play.pressed.connect(start_run);menu.add_child(play)
	var hint:=label("BAŞLAMAK İÇİN DOKUN",18);hint.position=Vector2(0,640);hint.size=Vector2(540,38);menu.add_child(hint)
	var cards:=HBoxContainer.new();cards.position=Vector2(8,704);cards.size=Vector2(524,210);cards.add_theme_constant_override("separation",8);menu.add_child(cards)
	for i in range(3):
		var card:=VBoxContainer.new();card.custom_minimum_size=Vector2(169,205);card.add_theme_stylebox_override("panel",style(Color(.06,.25,.37,.88)));cards.add_child(card)
		card.add_child(label(["🏹","🛷","🪙"][i],36));card.add_child(label(["FIRLATICI","KIZAK","KAZANÇ"][i],17))
		var up:=button("SEVİYE 1 • 🪙 120",Color("efb32e"));up.custom_minimum_size=Vector2(158,52);up.add_theme_font_size_override("font_size",14);up.pressed.connect(upgrade.bind(i));card.add_child(up);upgrade_buttons.append(up)
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.visible=false;layer.add_child(hud)
	coins_text=label("🪙 0",19);coins_text.position=Vector2(15,18);coins_text.size=Vector2(110,45);coins_text.add_theme_stylebox_override("normal",style(Color(.04,.2,.3,.75)));hud.add_child(coins_text)
	distance_text=label("0 m",25);distance_text.position=Vector2(170,23);distance_text.size=Vector2(200,42);hud.add_child(distance_text)
	speed_text=label("0\nkm/h",26);speed_text.position=Vector2(18,790);speed_text.size=Vector2(120,100);speed_text.add_theme_stylebox_override("normal",style(Color(.04,.23,.33,.75),50));hud.add_child(speed_text)
	progress=ProgressBar.new();progress.position=Vector2(495,100);progress.size=Vector2(20,520);progress.max_value=1800;progress.show_percentage=false;progress.add_theme_stylebox_override("background",style(Color(.05,.2,.3,.6),10));progress.add_theme_stylebox_override("fill",style(Color("22d3e7"),10));hud.add_child(progress)
	air_text=label("",21);air_text.position=Vector2(150,145);air_text.size=Vector2(240,48);air_text.add_theme_stylebox_override("normal",style(Color("edb52e")));air_text.visible=false;hud.add_child(air_text)
	result=Control.new();result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);result.visible=false;layer.add_child(result)
	var shade:=ColorRect.new();shade.color=Color(0,.08,.12,.72);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);result.add_child(shade)
	var panel:=Panel.new();panel.position=Vector2(55,190);panel.size=Vector2(430,520);panel.add_theme_stylebox_override("panel",style(Color("e9f8ff"),28));result.add_child(panel)
	result_text=label("",24,Color("174d68"));result_text.position=Vector2(30,35);result_text.size=Vector2(370,300);panel.add_child(result_text)
	var again:=button("TEKRAR OYNA",Color("20bddf"));again.position=Vector2(115,350);again.size=Vector2(200,62);again.pressed.connect(start_run);panel.add_child(again)
	var home:=button("ANA MENÜ",Color("5d7180"));home.position=Vector2(115,430);home.size=Vector2(200,58);home.pressed.connect(show_menu);panel.add_child(home)

func _input(e:InputEvent):
	if state!="ride":return
	if e is InputEventScreenDrag:target_x=clamp(target_x+e.relative.x*.02,-TRACK_HALF,TRACK_HALF)
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):target_x=clamp(target_x+e.relative.x*.02,-TRACK_HALF,TRACK_HALF)

func _process(dt:float):
	if state=="menu":player.rotation.y=sin(Time.get_ticks_msec()*.0006)*.1;return
	if state!="ride":return
	immunity=max(0.0,immunity-dt);distance+=speed*dt;speed=clamp(speed+dt*(.55+sled*.08),17.0,42.0+sled)
	player.position.x=lerp(player.position.x,target_x,dt*7.5);player.rotation.z=lerp(player.rotation.z,-(target_x-player.position.x)*.12,dt*8)
	if airborne:
		y_speed-=18*dt;player.position.y+=y_speed*dt;air_time+=dt;air_text.visible=true;air_text.text="HAVADA %.1f sn"%air_time
		if player.position.y<=.32:player.position.y=.32;airborne=false;best_air=max(best_air,air_time);air_text.visible=false;speed+=min(5,air_time*1.4)
	else:player.position.y=.32+sin(Time.get_ticks_msec()*.012)*.035
	for t in tiles:
		t.position.z+=speed*dt
		if t.position.z>30:t.position.z-=418
	for d in scenery:
		d.position.z+=speed*dt
		if d.position.z>18:respawn_scenery(d)
	for o in objects:
		o.position.z+=speed*dt
		if o.get_meta("kind")=="coin":o.rotation.y+=dt*4
		if o.position.z>10:place(o)
		elif o.visible and abs(o.position.z)<1.8 and abs(o.position.x-player.position.x)<1.3:hit(o)
	camera.position.x=lerp(camera.position.x,player.position.x*.16,dt*3);camera.look_at_from_position(camera.position,Vector3(player.position.x*.2,1.1,-13))
	speed_text.text="%d\nkm/h"%int(speed*3.6);distance_text.text="%d m"%int(distance);coins_text.text="🪙 %d"%run_coins;progress.value=fmod(distance,1800)
	if distance>=1800+level*250:finish()

func hit(o:Node3D):
	var k:String=o.get_meta("kind");o.visible=false
	if k=="coin":run_coins+=income
	elif k=="ramp":airborne=true;y_speed=10.5;air_time=0;speed+=4
	elif k=="boost":speed+=8
	elif k=="gate":run_coins+=5
	elif immunity<=0:speed*=.58;immunity=1.1;player.rotation_degrees.z=16 if o.position.x<player.position.x else -16

func start_run():
	state="ride";menu.visible=false;result.visible=false;hud.visible=true;speed=24+launcher*1.8;distance=0;target_x=0;run_coins=0;airborne=false;air_time=0;best_air=0;immunity=0;spawn_z=-35;player.position=Vector3(0,.32,0);player.rotation=Vector3.ZERO;camera.position=Vector3(0,5.7,9.5)
	for i in objects.size():place(objects[i],true,i)
func finish():
	state="result";hud.visible=false;result.visible=true;coins+=run_coins;best=max(best,int(distance));level+=1;gems+=2
	result_text.text="BÖLÜM TAMAMLANDI!\n\n%d METRE\n🪙 +%d ALTIN\n✈ %.1f sn HAVADA\n🏆 EN İYİ %d m"%[int(distance),run_coins,best_air,best];save_game();update_ui()
func show_menu():
	state="menu";hud.visible=false;result.visible=false;menu.visible=true;camera.position=Vector3(0,4.9,8.7);camera.look_at_from_position(camera.position,Vector3(0,1.8,0));update_ui()
func show_tasks():
	menu.visible=false;result.visible=true;result_text.text="GÜNLÜK GÖREVLER\n\n• 500 m git\n• 25 altın topla\n• 3 rampadan uç\n\nÖDÜL: 💎 5"
func upgrade(i:int):
	var levels=[launcher,sled,income];var cost=120*levels[i]
	if coins<cost:return
	coins-=cost
	if i==0:launcher+=1
	elif i==1:sled+=1
	else:income+=1
	save_game();update_ui()
func update_ui():
	if not menu:return
	menu.get_node("Currencies").text="🎟 20     🪙 %d     💎 %d"%[coins,gems];menu.get_node("Level").text="LEVEL %d"%level
	var levels=[launcher,sled,income]
	for i in upgrade_buttons.size():upgrade_buttons[i].text="SEVİYE %d • 🪙 %d"%[levels[i],120*levels[i]]
func save_game():
	var f:=FileAccess.open("user://save_v4.json",FileAccess.WRITE);f.store_string(JSON.stringify({"coins":coins,"gems":gems,"best":best,"level":level,"launcher":launcher,"sled":sled,"income":income}))
func load_game():
	if FileAccess.file_exists("user://save_v4.json"):
		var d=JSON.parse_string(FileAccess.get_file_as_string("user://save_v4.json"))
		if d is Dictionary:coins=d.get("coins",350);gems=d.get("gems",12);best=d.get("best",0);level=d.get("level",1);launcher=d.get("launcher",1);sled=d.get("sled",1);income=d.get("income",1)
