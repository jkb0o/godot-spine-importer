tool
extends Control

const AtlasReader = preload("atlas_reader.gd")

#var source_file = "res://spineboy/spineboy-hover.json"
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
	f.open(source_file, File.READ)
	data = {}
	data.parse_json(f.get_as_text())
	var order = 0
	for slot in data["slots"]:
		slots[slot["name"]] = slot
		slot["order"] = order
		order += 0.1
	
	import_skeleton()
	import_meshes()
	import_animations()
	
	
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
		bone["rot"] = rot

		if bone.has("inheritRotation") && !bone["inheritRotation"]:
			var cidx = idx
			while skeleton.get_bone_parent(cidx) >= 0:
				cidx = skeleton.get_bone_parent(cidx)
				rot -= bones[skeleton.get_bone_name(cidx)]["rot"]
			
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
			if attachment == skin_name:
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
	
	var mt = MeshTool.new()
	#var st = SurfaceTool.new()
	#st.begin(Mesh.PRIMITIVE_TRIANGLES)

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
			mt.add_uv(uv)
			mt.add_bones([current_bone_index, -1, -1, -1])
			mt.add_weights([1,0,0,0])
			mt.add_vertex(vert)
			#st.add_uv(uv)
			#st.add_bones([current_bone_index, -1, -1, -1])
			#st.add_weights([1,0,0,0])
			#st.add_vertex(vert)
			indices.pop_front()


	#print("Vertices found: ", vertices, " triangles: ", data["triangles"].size())
	mt.index()
	#st.index()
	return mt.build_mesh()
	#return st.commit()
	
	
	
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
	var x = 0
	if data.has("x"):
		x = data["x"]*0.01
	var y = 0
	if data.has("y"):
		y = data["y"]*0.01
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
	
var player
func import_animations():
	player = AnimationPlayer.new()
	skeleton.add_child(player)
	player.set_name("player")
	player.set_owner(skeleton)
	for anim_name in data["animations"]:
		import_animation(anim_name)

func import_animation(animation_name):
	var anim_data = data["animations"][animation_name]
	var bones_data = anim_data["bones"]
	var slots_data = anim_data["slots"]
	var time = detect_animation_time(anim_data)
	var animation = Animation.new()
	animation.set_name(animation_name)
	animation.set_step(0.0666)
	animation.set_length(time)
	var steps = time / 0.0666
	var idx = 0
	for bone in bones_data:
		var bone_data = bones_data[bone]
		var transforms = []
		var quats = []
		var scales = []
		for i in range(steps):
			transforms.append(Vector3())
			quats.append(Quat())
			scales.append(Vector3(1,1,1))
			
		print("add animation for bone ", bone)
		if bone_data.has("rotate"):
			animation.add_track(Animation.TYPE_TRANSFORM)
			for key_data in bone_data["rotate"]:
				var rot = Quat(Vector3(0,0,1), -deg2rad(key_data["angle"]))
				animation.transform_track_insert_key(idx, key_data["time"], Vector3(), rot, Vector3(1,1,1))
			for step in range(steps):
				quats[step] = animation.transform_track_interpolate(idx, step*0.0666)[1]
			animation.remove_track(idx)
		if bone_data.has("translate"):
			animation.add_track(Animation.TYPE_TRANSFORM)
			for key_data in bone_data["translate"]:
				var trans = Vector3(key_data["x"]*0.01, key_data["y"]*0.01, 0)
				animation.transform_track_insert_key(idx, key_data["time"], trans, Quat(), Vector3(1,1,1))
			for step in range(steps):
				transforms[step] = animation.transform_track_interpolate(idx, step*0.0666)[0]
			animation.remove_track(idx)
		if bone_data.has("scale"):
			animation.add_track(Animation.TYPE_TRANSFORM)
			for key_data in bone_data["scale"]:
				var scale = Vector3(key_data["x"], key_data["y"], 1)
				animation.transform_track_insert_key(idx, key_data["time"], Vector3(), Quat(), scale)
			for step in range(steps):
				scales[step] = animation.transform_track_interpolate(idx, step*0.0666)[2]
			animation.remove_track(idx)
		animation.add_track(Animation.TYPE_TRANSFORM)
		animation.track_set_path(idx, ".:" + bone)
		for step in range(steps):
			animation.transform_track_insert_key(idx, step*0.0666, transforms[step], quats[step], scales[step])


		idx += 1
	
	player.add_animation(animation_name, animation)
	
	
func detect_animation_time(anim_data):
	var time = 0
	for bone in anim_data["bones"]:
		for curve in ["rotate", "translate", "scale"]:
			if anim_data["bones"][bone].has(curve):
				for curve_data in anim_data["bones"][bone][curve]:
					time = max(time, curve_data["time"])
	return time
	

class Vertex:
	extends Reference
	var pos = Vector3()
	var uv = Vector2()
	var bones = IntArray()
	var weights = FloatArray()
	
class MeshTool:
	extends Reference
	var verts = []
	var indices = IntArray()
	var last_uv
	var last_bones
	var last_weights
	
	func add_vertex(vert):
		var v = Vertex.new()
		v.pos = vert
		v.uv = last_uv
		v.bones = last_bones
		v.weights = last_weights
		last_uv = null
		last_bones = null
		last_weights = null
		verts.append(v)
	func add_uv(uv):
		last_uv = uv
	func add_bones(bones):
		last_bones = IntArray(bones)
	func add_weights(weights):
		last_weights = FloatArray(weights)
	func index():
		var new_verts = []
		var index_map = {}
		indices = IntArray()

		for vert in verts:
			var idx
			if !index_map.has(vert.pos):
				idx = index_map.size()
				new_verts.append(vert)
				index_map[vert.pos] = idx
			else:
				idx = index_map[vert.pos]
			indices.append(idx)
		verts = new_verts
			
	func build_mesh():
		var mesh = Mesh.new()
		var vert_array = Vector3Array()
		var uvs_array = Vector2Array()
		var bones_array = FloatArray()
		var weights_array = FloatArray()
		for vert in verts:
			vert_array.append(vert.pos)
			uvs_array.append(vert.uv)
			for bone in vert.bones:
				bones_array.append(bone)
			for weight in vert.weights:
				weights_array.append(weight)
			
		mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES,[
			vert_array,
			null,
			null,
			null,
			uvs_array,
			null,
			bones_array,
			weights_array,
			indices
		])
		return mesh