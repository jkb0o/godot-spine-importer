tool
extends Control

var source_file = "res://spineboy/spineboy-mesh.json"
var target_path = "res://spineboy-gen/"


func _ready():
	print("ready")
	get_node("button").connect("pressed", self, "import")
	
	
func import():
	print("pizdez")
	return
	import_meshes()
	

func import_meshes():
	var f = File.new()
	f.open("res://spineboy/spineboy-mesh.json", File.READ)
	var data = {}
	data.parse_json(f.get_as_text())
	
	for slot_name in data["skins"]["default"]:
		for skin_name in data["skins"]["default"][slot_name]:
			var mesh = create_mesh(data["skins"]["default"][slot_name][skin_name])
			
func create_mesh(data):
	pass
	
func create_complex_mesh(data):
	pass
	
func create_simple_mesh(data):
	var x = data["x"]*0.01
	var y = data["y"]*0.01
	var w = data["width"]*0.01
	var h = data["height"]*0.01
	var st = SurfaceTool.new()
	st.add_uv(Vector2())
	st.add_vertex(Vector3(x, y, 0))
	st.add_uv(Vector2(1,0))
	#st.add_vertex(Vector3(x+w,