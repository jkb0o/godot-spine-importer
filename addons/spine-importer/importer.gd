tool
extends Control

const AtlasReader = preload("atlas_reader.gd")

var source_file = "res://spineboy/spineboy-mesh.json"
var target_path = "res://spineboy-gen/"
var slots = {}
var skeleton
var data
var current_bone_index


func _ready():
	print("ready")
	get_node("button").connect("pressed", self, "import")
	
func import():
	AtlasReader.import("res://spineboy/spineboy.atlas", target_path)
	
	var f = File.new()
	f.open("res://spineboy/spineboy-mesh.json", File.READ)
	data = {}
	data.parse_json(f.get_as_text())
	var order = 0
	for slot in data["slots"]:
		slots[slot["name"]] = slot
		slot["order"] = order
		order += 0.1
	
	import_skeleton()
	import_meshes()
	
	
func import_skeleton():
	var bones = {}
	skeleton = Skeleton.new()
	get_node("/root/EditorNode").set_edited_scene(skeleton)
	var idx = 0
	for bone in data["bones"]:
		bone["idx"] = idx
		bones[bone["name"]] = bone
		skeleton.add_bone(bone["name"])
		if bone.has("parent"):
			skeleton.set_bone_parent(idx, bones[bone["parent"]]["idx"])
		else:
			skeleton.set_bone_parent(idx, -1)
		var tr = Transform()
		var x = 0
		var y = 0
		var rot = 0
		if bone.has("x"):
			x = bone["x"]*0.01
		if bone.has("y"):
			y = bone["y"]*0.01
		if bone.has("rotation"):
			rot = -deg2rad(bone["rotation"])
		tr = tr.rotated(Vector3(0,0,1),rot)
		tr.origin = Vector3(x,y,0)
		skeleton.set_bone_rest(idx, tr)
		idx += 1
			
		
		
	
	var scene = PackedScene.new()
	scene.pack(skeleton)
	ResourceSaver.save(target_path+"skeleton.tscn", scene)
		
			

func import_meshes():
	var material = create_material(data)
	ResourceSaver.save(target_path + "material.tres", material)
	
	for slot_name in data["skins"]["default"]:
		current_bone_index = skeleton.find_bone(slots[slot_name]["bone"])
		var slot = Spatial.new()
		var attachment = null
		if slots[slot_name].has("attachment"):
			attachment = slots[slot_name]["attachment"]
		slot.set_name(slot_name)
		skeleton.add_child(slot)
		slot.global_translate(Vector3(0, 0, slots[slot_name]["order"]))
		slot.set_owner(skeleton)
		for skin_name in data["skins"]["default"][slot_name]:
			var tex = load(target_path + "spineboy/" + skin_name + ".xml")

			var mesh = create_mesh(data["skins"]["default"][slot_name][skin_name], tex)
			if !mesh:
				continue
			mesh.surface_set_material(0, material)	
			var mesh_instance = MeshInstance.new()
			slot.add_child(mesh_instance)
			mesh_instance.set_owner(skeleton)
			mesh_instance.set_mesh(mesh)
			#mesh_instance.set_transform(skeleton.get_bone_global_pose(current_bone_index))
			mesh_instance.set_name(skin_name)
			mesh_instance.set_skeleton_path("../..")
			if !attachment || attachment == skin_name:
				mesh_instance.show()
			else:
				mesh_instance.hide()

			
func create_mesh(data, tex):
	if data.has("type") && data["type"] == "mesh":
		if data["vertices"].size() > data["uvs"].size():
			return create_weight_mesh(data, tex)
		else:
			return create_static_mesh(data, tex)
	else:
		return create_simple_mesh(data, tex)

func create_static_mesh(data, tex):
	var atlas = tex.get_atlas()
	var u_min = tex.get_region().pos.x / float(atlas.get_width())
	var u_max = tex.get_region().end.x / float(atlas.get_width())
	var v_min = tex.get_region().pos.y / float(atlas.get_height())
	var v_max = tex.get_region().end.y / float(atlas.get_height())
	var tr = skeleton.get_bone_global_pose(current_bone_index)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var vertices = []
	var uvs = []
	for idx in range(data["vertices"].size()*0.5):
		vertices.append(tr * Vector3(data["vertices"][idx*2]*0.01, data["vertices"][idx*2+1]*0.01, 0))
		if tex.rotate:
			uvs.append(Vector2(lerp(u_min, u_max, data["uvs"][idx*2+1]), lerp(v_min, v_max, 1-data["uvs"][idx*2])))
		else:
			uvs.append(Vector2(lerp(u_min, u_max, data["uvs"][idx*2]), lerp(v_min, v_max, data["uvs"][idx*2+1])))
	
	var indices = data["triangles"]
	while indices.size():
		for sidx in range(3):
			var vert = vertices[indices[0]]
			var uv = uvs[indices[0]]
			st.add_uv(uv)
			st.add_bones([current_bone_index, -1, -1, -1])
			st.add_weights([1,0,0,0])
			st.add_vertex(vert)
			indices.pop_front()


	#print("Vertices found: ", vertices, " triangles: ", data["triangles"].size())

	st.index()
	return st.commit()
	
	
	
func create_weight_mesh(data, tex):
	var atlas = tex.get_atlas()
	var u_min = tex.get_region().pos.x / float(atlas.get_width())
	var u_max = tex.get_region().end.x / float(atlas.get_width())
	var v_min = tex.get_region().pos.y / float(atlas.get_height())
	var v_max = tex.get_region().end.y / float(atlas.get_height())
	
	var vertices = []
	var uvs = []
	var src_data = Array(data["vertices"])
	while src_data.size():
		var info = {"bones":[],"weights":[],"verts":[]}
		vertices.append(info)
		var bones_count = src_data[0]
		src_data.pop_front()
		for i in range(bones_count):
			if i < 4:
				info["bones"].append(src_data[0])
				info["verts"].append(Vector3(src_data[1]*0.01, src_data[2]*0.01, 0))
				info["weights"].append(src_data[3])
			for j in range(4):
				src_data.pop_front()
		
	for info in vertices:
		var weight_pos = null
		for i in range(info["bones"].size()):
			var bone_tr = skeleton.get_bone_global_pose(info["bones"][i])
			if !i:
				weight_pos = bone_tr * info["verts"][i]
			else:
				weight_pos = weight_pos.linear_interpolate(bone_tr * info["verts"][i], info["weights"][i-1])
		info["vert"] = weight_pos
		info.erase("verts")
		for i in range(4-info["bones"].size()):
			info["bones"].append(-1)
			info["weights"].append(0)
			
	for idx in range(data["uvs"].size()*0.5):
		if tex.rotate:
			uvs.append(Vector2(lerp(u_min, u_max, data["uvs"][idx*2+1]), lerp(v_min, v_max, 1-data["uvs"][idx*2])))
		else:
			uvs.append(Vector2(lerp(u_min, u_max, data["uvs"][idx*2]), lerp(v_min, v_max, data["uvs"][idx*2+1])))
		
	
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices = data["triangles"]
	while indices.size():
		for sidx in range(3):
			var vert = vertices[indices[0]]
			var uv = uvs[indices[0]]
			st.add_uv(uv)
			st.add_bones(vert["bones"])
			st.add_weights(vert["weights"])
			st.add_vertex(vert["vert"])
			indices.pop_front()
			
	st.index()
	return st.commit()
	
func create_simple_mesh(data, tex):
	#return null
	if !data.has("width"):
		return null
	var atlas = tex.get_atlas()
	var u_min = tex.get_region().pos.x / float(atlas.get_width())
	var u_max = tex.get_region().end.x / float(atlas.get_width())
	var v_min = tex.get_region().pos.y / float(atlas.get_height())
	var v_max = tex.get_region().end.y / float(atlas.get_height())
	var w = data["width"]*0.01 * 0.5
	var h = data["height"]*0.01 * 0.5
	var x = data["x"]*0.01
	var y = data["y"]*0.01
	var rot = 0
	if data.has("rotation"):
		rot = -deg2rad(data["rotation"])
		#tr = tr.translated(Vector3(x,y,0))
	var tr = Transform()
	tr = tr.rotated(Vector3(0,0,1),rot)
	tr.origin = Vector3(x,y,0)
	
	var gtr = skeleton.get_bone_global_pose(current_bone_index)
	tr = gtr * tr
		
	var vs = [tr*Vector3(-w,-h,0),tr*Vector3(w,-h,0),tr*Vector3(w,h,0),tr*Vector3(-w,h,0)]
	var uv = [Vector2(u_min,v_min),Vector2(u_max,v_min),Vector2(u_max,v_max),Vector2(u_min,v_max)]
	vs.invert()
	if tex.rotate:
		print("Rotating texture")
		uv = [uv[3],uv[0],uv[1],uv[2]]
	#uv.invert()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_uv(uv[0])
	st.add_bones([current_bone_index, -1, -1, -1])
	st.add_weights([1,0,0,0])
	st.add_vertex(vs[0])
	st.add_uv(uv[1])
	st.add_bones([current_bone_index, -1, -1, -1])
	st.add_weights([1,0,0,0])
	st.add_vertex(vs[1])
	st.add_uv(uv[2])
	st.add_bones([current_bone_index, -1, -1, -1])
	st.add_weights([1,0,0,0])
	st.add_vertex(vs[2])
	
	st.add_bones([current_bone_index, -1, -1, -1])
	st.add_weights([1,0,0,0])
	st.add_vertex(vs[2])
	st.add_uv(uv[3])
	st.add_bones([current_bone_index, -1, -1, -1])
	st.add_weights([1,0,0,0])
	st.add_vertex(vs[3])
	st.add_uv(uv[0])
	st.add_bones([current_bone_index, -1, -1, -1])
	st.add_weights([1,0,0,0])
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
	
