tool
extends Control

const AtlasReader = preload("atlas_reader.gd")

var source_file = "res://spineboy/spineboy-mesh.json"
var target_path = "res://spineboy-gen/"


func _ready():
	print("ready")
	get_node("button").connect("pressed", self, "import")
	
func import():
	AtlasReader.import("res://spineboy/spineboy.atlas", target_path)
	
	var f = File.new()
	f.open("res://spineboy/spineboy-mesh.json", File.READ)
	var data = {}
	data.parse_json(f.get_as_text())
	import_meshes(data)
	import_skeleton(data)
	
	
func import_skeleton(data):
	var bones = {}
	var skeleton = Skeleton.new()
	get_node("/root/EditorNode").set_edited_scene(skeleton)
	var idx = 0
	for bone in data["bones"]:
		print("Add bone ", bone["name"], " ", idx)
		bone["idx"] = idx
		bones[bone["name"]] = bone
		skeleton.add_bone(bone["name"])
		var tr = Transform()
		var x = 0
		var y = 0
		var rot = 0
		if bone.has("x"):
			x = bone["x"]*0.01
		if bone.has("y"):
			y = bone["y"]*0.01
		if bone.has("rotation"):
			rot = deg2rad(bone["rotation"])
		tr = tr.translated(Vector3(x,y,0))
		tr = tr.rotated(Vector3(0,0,1),rot)
		skeleton.set_bone_rest(idx, tr)
		if bone.has("parent"):
			skeleton.set_bone_parent(idx, bones[bone["parent"]]["idx"])
		else:
			skeleton.set_bone_parent(idx, -1)
		idx += 1
		#if idx == 6:
		#	break
		
		
	for slot in data["slots"]:
		var mesh
		for skin_name in data["skins"]["default"][slot["name"]]:
			#var skin = data["skins"]["default"][slot["name"]][skin_name]
			mesh = load(target_path + slot["name"] + "." + skin_name + ".tres")
			if mesh != null:
				break
		if mesh != null:
			print("Found mesh at " + mesh.get_path())
			var mesh_instance = MeshInstance.new()
			skeleton.add_child(mesh_instance)
			mesh_instance.set_owner(skeleton)
			mesh_instance.set_mesh(mesh)
			var idx = skeleton.find_bone(slot["bone"])
			var tr = skeleton.get_bone_global_pose(idx)
			mesh_instance.set_transform(tr)
			
			
		
		
	
	var scene = PackedScene.new()
	scene.pack(skeleton)
	ResourceSaver.save(target_path+"skeleton.tscn", scene)
		
			

func import_meshes(data):
	var material = create_material(data)
	ResourceSaver.save(target_path + "material.tres", material)
	
	for slot_name in data["skins"]["default"]:
		for skin_name in data["skins"]["default"][slot_name]:
			var tex = load(target_path + "spineboy/" + skin_name + ".xml")
			var mesh = create_mesh(data["skins"]["default"][slot_name][skin_name], tex)
			if mesh:
				var path = target_path + slot_name + "." + skin_name + ".tres"
				print("Saving to ", path, " ", mesh.get_surface_count())
				mesh.surface_set_material(0, material)
				ResourceSaver.save(path, mesh)
			
func create_mesh(data, tex):
	if data.has("type") && data["type"] == "mesh":
		return create_complex_mesh(data, tex)
	else:
		return create_simple_mesh(data, tex)
	
func create_complex_mesh(data, tex):
	print("uvs: ", data["uvs"].size(), " triangles: ", data["triangles"].size(), " vertices: ", data["vertices"].size(), " edges: ", data["edges"].size())
	var vertices = []
	if data["vertices"] > data["uvs"]: # weighted mesh
		while data["vertices"].size():
			var v = {"bones":[],"weights":[]}
			var num_bones = data["vertices"][0]
			data["vertices"].pop_front()
			for i in range(num_bones):
				v["bones"].append(data["vertices"][0])
				data["vertices"].pop_front()
				v["weights"].append(data["vertices"][0])
				data["vertices"].pop_front()
				v["weights"].append(data["vertices"][0])
				data["vertices"].pop_front()
				v["weights"].append(0)
			vertices.append(v)
	else:
		for i in range(data["vertices"].size()*0.5):
			vertices.append(Vector3(data["vertices"][i*2], data["vertices"][i*2+1], 0))
	print("Vertices: ", vertices)
	
func create_simple_mesh(data, tex):
	if !data.has("width"):
		return null
	var atlas = tex.get_atlas()
	var u_min = tex.get_region().pos.x / float(atlas.get_width())
	var u_max = tex.get_region().end.x / float(atlas.get_width())
	var v_min = tex.get_region().pos.y / float(atlas.get_height())
	var v_max = tex.get_region().end.y / float(atlas.get_height())
	var w = data["width"]*0.01
	var h = data["height"]*0.01
	var x = data["x"]*0.01# - w*0.5
	var y = data["y"]*0.01# - h*0.5
	var vs = [Vector3(x,y,0),Vector3(x+w,y,0),Vector3(x+w,y+h,0),Vector3(x,y+h,0)]
	var uv = [Vector2(u_min,v_min),Vector2(u_max,v_min),Vector2(u_max,v_max),Vector2(u_min,v_max)]
	vs.invert()
	if tex.rotate:
		print("Rotating texture")
		uv = [uv[3],uv[0],uv[1],uv[2]]
	#uv.invert()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_uv(uv[0])
	st.add_vertex(vs[0])
	st.add_uv(uv[1])
	st.add_vertex(vs[1])
	st.add_uv(uv[2])
	st.add_vertex(vs[2])
	
	st.add_vertex(vs[2])
	st.add_uv(uv[3])
	st.add_vertex(vs[3])
	st.add_uv(uv[0])
	st.add_vertex(vs[0])
	st.index()
	
	return st.commit()

func create_material(data):
	var mat = FixedMaterial.new()
	mat.set_flag(Material.FLAG_UNSHADED, true)
	#mat.set_flag(Material.FLAG_DOUBLE_SIDED, true)
	mat.set_fixed_flag(FixedMaterial.FLAG_USE_ALPHA, true)
	mat.set_texture(FixedMaterial.PARAM_DIFFUSE, load("res://spineboy/spineboy.png"))
	return mat
	
