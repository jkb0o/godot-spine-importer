
extends Spatial

# member variables here, example:
# var a=2
# var b="textvar"

var texture = preload("res://spineboy/spineboy.png")

func _ready():
	var f = File.new()
	f.open("res://spineboy/spineboy-mesh.json", File.READ)
	var data = {}
	data.parse_json(f.get_as_text())
	
	for slot_name in data["skins"]["default"]:
		for skin_name in data["skins"]["default"][slot_name]:
			var mesh = create_mesh(data["skins"]["default"][slot_name][skin_name])


func create_mesh(data):
	if data.has("type") && data["type"] == "mesh":
		return create_complex_mesh(data)
	else:
		return create_quad_mesh(data)
		
func create_complex_mesh(data):
	pass
	
func create_quad_mesh(data):
	pass
