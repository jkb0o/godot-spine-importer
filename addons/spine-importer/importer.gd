# ************************************************************************
# importer.gd
# ************************************************************************
#                          This file is part of:
#                     Spine importer for Godotengine
#              https://github.com/jjay/godot-spine-importer/
# 
# ************************************************************************
# 
#  Copyright (c) 2016 Yakov Borevich
# 
#  Permission is hereby granted, free of charge, to any person obtaining
#  a copy of this software and associated documentation files (the
#  "Software"), to deal in the Software without restriction, including
#  without limitation the rights to use, copy, modify, merge, publish,
#  distribute, sublicense, and/or sell copies of the Software, and to
#  permit persons to whom the Software is furnished to do so, subject to
#  the following conditions:
# 
#  The above copyright notice and this permission notice shall be
#  included in all copies or substantial portions of the Software.
# 
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
#  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# 
# ************************************************************************

tool
extends Node

const AtlasReader = preload("atlas_reader.gd")

var atlas_path = null
var json_pathes = null
var target_path = null

var import_deform = false
var images = {}
var slots = {}
var bones = {}
var root
var viewport
var skeleton
var scene_3d
var data
var current_bone_index
var current_slot
var current_attachment

	
func import():
	images = AtlasReader.import(atlas_path, target_path)
	
	var f = File.new()
	for source_file in json_pathes:
		f.open(source_file, File.READ)
		data = {}
		bones = {}
		slots = {}
		data.parse_json(f.get_as_text())
		var order = 0
		
		for slot in data["slots"]:
			slots[slot["name"]] = slot
			slot["order"] = order
			order += 0.1
		for bone in data["bones"]:
			bones[bone["name"]] = bone
			
		
		
		create_template()
		import_skeleton()
		import_meshes()
		import_animations()
	
func create_template():
	root = Node2D.new()
	root.set_name("spine")
	get_node("/root/EditorNode").set_edited_scene(root)
	viewport = Viewport.new()
	root.add_child(viewport)
	viewport.set_owner(root)
	viewport.set_name("viewport")
	viewport.set_as_render_target(true)
	viewport.set_rect(Rect2(0, 0, 512, 512))
	viewport.set_script(preload("viewport.gd"))
	scene_3d = Spatial.new()
	scene_3d.set_name("scene")
	viewport.add_child(scene_3d)
	scene_3d.set_owner(root)
	var camera = Camera.new()
	camera.set_orthogonal(5, 0.1, 20)
	camera.set_name("camera")
	scene_3d.add_child(camera)
	camera.translate(Vector3(0, 0, 10))
	camera.set_owner(root)
	camera.make_current()
	var sprite = ViewportSprite.new()
	root.add_child(sprite)
	sprite.set_name("sprite")
	sprite.set_owner(root)
	sprite.set_viewport_path(sprite.get_path_to(viewport))
	
func import_skeleton():
	var bones = {}
	skeleton = preload("skeleton.gd").new()
	scene_3d.add_child(skeleton)
	skeleton.set_owner(root)
	var idx = 0
	for bone in data["bones"]:
		bone["idx"] = idx
		bones[bone["name"]] = bone
		skeleton.add_bone(bone["name"])
		if bone.has("parent"):
			skeleton.set_bone_parent(idx, bones[bone["parent"]]["idx"])
		else:
			skeleton.set_bone_parent(idx, -1)
		var x = 0
		var y = 0
		var scale_x = 1
		var scale_y = 1
		var rot = 0
		if bone.has("x"):
			x = bone["x"]*0.01
		if bone.has("y"):
			y = bone["y"]*0.01
		if bone.has("scaleX"):
			scale_x = bone["scaleX"]
		if bone.has("scaleY"):
			scale_y = bone["scaleY"]
		if bone.has("rotation"):
			rot = -deg2rad(bone["rotation"])
		bone["rot"] = rot

		if bone.has("inheritRotation") && !bone["inheritRotation"]:
			var cidx = idx
			while skeleton.get_bone_parent(cidx) >= 0:
				cidx = skeleton.get_bone_parent(cidx)
				rot -= bones[skeleton.get_bone_name(cidx)]["rot"]
		
		var tr = Transform()
		tr = tr.rotated(Vector3(0,0,1),rot)
		tr = tr.scaled(Vector3(scale_x, scale_y, 1))
		tr.origin = Vector3(x,y,0)
		skeleton.set_bone_rest(idx, tr)

		idx += 1
			
		
		
	
	var scene = PackedScene.new()
	scene.pack(skeleton)
	ResourceSaver.save(target_path+"skeleton.tscn", scene)
		
func attachment_binded_to_single_bone(slot, attachment):
	var a = data["skins"]["default"][slot][attachment]
	if a.has("type") && a["type"] == "mesh" && a["vertices"].size() > a["uvs"].size():
		return false
	else:
		return true

func import_meshes():
	for slot_name in data["skins"]["default"]:
		current_bone_index = skeleton.find_bone(slots[slot_name]["bone"])
		current_slot = slot_name
		var slot = Spatial.new()
		var attachment = null
		if slots[slot_name].has("attachment"):
			attachment = slots[slot_name]["attachment"]
		slot.set_name(slot_name)
		skeleton.add_child(slot)
		slot.global_translate(Vector3(0, 0, slots[slot_name]["order"]))
		slot.set_owner(root)
		for skin_name in data["skins"]["default"][slot_name]:
			current_attachment = skin_name
			if !images.has(skin_name):
				continue
			var image = images[skin_name]

			var mesh = create_mesh(data["skins"]["default"][slot_name][skin_name], image)
			if !mesh:
				continue
			mesh.surface_set_material(0, create_material(slot_name, skin_name))	
			var mesh_instance = MeshInstance.new()
			slot.add_child(mesh_instance)
			mesh_instance.set_owner(root)
			mesh_instance.set_mesh(mesh)
			#mesh_instance.set_transform(skeleton.get_bone_global_pose(current_bone_index))
			mesh_instance.set_name(skin_name)
			if attachment == skin_name:
				mesh_instance.show()
			else:
				mesh_instance.hide()
			if attachment_binded_to_single_bone(current_slot, current_attachment):
				skeleton.bind_child_node_to_bone(current_bone_index, mesh_instance)
			else:
				mesh_instance.set_skeleton_path("../..")

			
func create_mesh(data, image):
	if data.has("type") && data["type"] == "mesh":
		if data["vertices"].size() > data["uvs"].size():
			return create_weight_mesh(data, image)
		else:
			return create_static_mesh(data, image)
	else:
		return create_simple_mesh(data, image)
			
func create_static_mesh(data, image):
	var atlas = image.texture
	var u_min = image.rect.pos.x / float(atlas.get_width())
	var u_max = image.rect.end.x / float(atlas.get_width())
	var v_min = image.rect.pos.y / float(atlas.get_height())
	var v_max = image.end.y / float(atlas.get_height())
	var tr = Transform()#skeleton.get_bone_global_pose(current_bone_index)

	var mt = MeshTool.new()
	var vertices = []
	var uvs = []
	for idx in range(data["vertices"].size()*0.5):
		vertices.append(tr * Vector3(data["vertices"][idx*2]*0.01, data["vertices"][idx*2+1]*0.01, 0))
		if image.rotate:
			uvs.append(Vector2(lerp(u_min, u_max, data["uvs"][idx*2+1]), lerp(v_min, v_max, 1-data["uvs"][idx*2])))
		else:
			uvs.append(Vector2(lerp(u_min, u_max, data["uvs"][idx*2]), lerp(v_min, v_max, data["uvs"][idx*2+1])))
	
	var indices = Array(data["triangles"])
	for idx in indices:
		var vert = vertices[idx]
		var uv = uvs[idx]
		mt.add_uv(uv)
		#mt.add_bones([current_bone_index, -1, -1, -1])
		#mt.add_weights([1,0,0,0])
		mt.add_vertex(vert)
	
	var mtr = Transform(tr.basis.x.normalized(), tr.basis.y.normalized(), tr.basis.z.normalized(), Vector3())
	for animation_name in self.data["animations"]:
		if !import_deform:
			break
		if !self.data["animations"][animation_name].has("deform"):
			continue
		for skin_name in self.data["animations"][animation_name]["deform"]:
			var animation_data = self.data["animations"][animation_name]["deform"][skin_name]
			if !(animation_data.has(current_slot) && animation_data[current_slot].has(current_attachment)):
				continue
			print("Add deform for " + current_slot + "/" + current_attachment)
			var deform_index = 0
			for deform_data in animation_data[current_slot][current_attachment]:
				mt.deform(animation_name + "_" + skin_name + "_" + str(deform_index))
				deform_index += 1
				var offset = 0
				if deform_data.has("offset"):
					offset = deform_data["offset"]
				for idx in indices:
					#var vert = Vector3(0, 0, 0)
					var vert = vertices[idx]
					if idx >= offset && deform_data["vertices"].size() >= 2*(idx-offset):
						vert += mtr*Vector3(deform_data["vertices"][2*(idx-offset)]*0.01, deform_data["vertices"][2*(idx-offset)+1]*0.01, 0)
					mt.add_vertex(vert)

	
	mt.index()
	return mt.build_mesh()

	
	
	
func create_weight_mesh(data, image):
	var atlas = image.texture
	var u_min = image.rect.pos.x / float(atlas.get_width())
	var u_max = image.rect.end.x / float(atlas.get_width())
	var v_min = image.rect.pos.y / float(atlas.get_height())
	var v_max = image.rect.end.y / float(atlas.get_height())
	
	var vertices = []
	var uvs = []
	var src_data = []
	for data_elem in data["vertices"]:
		src_data.append(data_elem)
	while src_data.size():
		var info = {"bones":[],"weights":[],"verts":[]}
		vertices.append(info)
		var bones_count = src_data[0]
		src_data.pop_front()
		var bone_weights = []
		for i in range(bones_count):
			bone_weights.append({
				"bone": src_data[0],
				"vert": Vector3(src_data[1]*0.01, src_data[2]*0.01, 0),
				"weight": src_data[3]
			})
			for j in range(4):
				src_data.pop_front()
		print("Add weight vertex ")
		bone_weights.sort_custom(self, "sort_weights")
		for i in range(bone_weights.size()):
			print("Add weight ", bone_weights[i]["weight"])
			info["bones"].append(bone_weights[i]["bone"])
			info["verts"].append(bone_weights[i]["vert"])
			info["weights"].append(bone_weights[i]["weight"])
			if i == 3:
				break


		
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
		while info["bones"].size() > 4:
			info["bones"].pop_back()
			info["weights"].pop_back()
			
		for i in range(4-info["bones"].size()):
			info["bones"].append(-1)
			info["weights"].append(0)
			
	for idx in range(data["uvs"].size()*0.5):
		if image.rotate:
			uvs.append(Vector2(lerp(u_min, u_max, data["uvs"][idx*2+1]), lerp(v_min, v_max, 1-data["uvs"][idx*2])))
		else:
			uvs.append(Vector2(lerp(u_min, u_max, data["uvs"][idx*2]), lerp(v_min, v_max, data["uvs"][idx*2+1])))
		
	
	
	var mt = MeshTool.new()
	var indices = data["triangles"]
	while indices.size():
		for sidx in range(3):
			var vert = vertices[indices[0]]
			var uv = uvs[indices[0]]
			mt.add_uv(uv)
			mt.add_bones(vert["bones"])
			mt.add_weights(vert["weights"])
			mt.add_vertex(vert["vert"])
			indices.pop_front()
	mt.index()
	
	return mt.build_mesh()

func sort_weights(one, two):
	return one["weight"] > two["weight"]
func create_simple_mesh(data, image):
	#return null
	if !data.has("width"):
		return null
	var atlas = image.texture
	var u_min = image.rect.pos.x / float(atlas.get_width())
	var u_max = image.rect.end.x / float(atlas.get_width())
	var v_min = image.rect.pos.y / float(atlas.get_height())
	var v_max = image.rect.end.y / float(atlas.get_height())
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
	
	var gtr = Transform()#skeleton.get_bone_global_pose(current_bone_index)
	tr = gtr * tr
		
	var vs = [tr*Vector3(-w,-h,0),tr*Vector3(w,-h,0),tr*Vector3(w,h,0),tr*Vector3(-w,h,0)]
	var uv = [Vector2(u_min,v_min),Vector2(u_max,v_min),Vector2(u_max,v_max),Vector2(u_min,v_max)]
	vs.invert()
	if image.rotate:
		uv = [uv[3],uv[0],uv[1],uv[2]]
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


var materials_cache = {}
func create_material(slot, attachment):
	var image = images[attachment]
	if materials_cache.has(image.texture):
		return materials_cache[image.texture]
	var mat = FixedMaterial.new()
	mat.set_flag(Material.FLAG_UNSHADED, true)
	#mat.set_flag(Material.FLAG_DOUBLE_SIDED, true)
	mat.set_fixed_flag(FixedMaterial.FLAG_USE_ALPHA, true)
	mat.set_texture(FixedMaterial.PARAM_DIFFUSE, image.texture)
	materials_cache[image.texture] = mat
	return mat
	
var player
func import_animations():
	player = AnimationPlayer.new()
	root.add_child(player)
	player.set_name("player")
	player.set_owner(root)
	for anim_name in data["animations"]:
		import_animation(anim_name)

func import_animation(animation_name):
	var anim_data = data["animations"][animation_name]
	var bones_data = {}
	if anim_data.has("bones"):
		bones_data = anim_data["bones"]
	var slots_data = {}
	if anim_data.has("slots"):
		slots_data = anim_data["slots"]
	var deform_data = {}
	if anim_data.has("deform"):
		deform_data = anim_data["deform"]
	var time = detect_animation_time(anim_data)
	print("Add animation ", animation_name, " : ", time, "s", ", bone tracks: ", bones_data.size())
	var animation = Animation.new()
	animation.set_name(animation_name)
	animation.set_step(0.0666)
	animation.set_length(time)
	var steps = time / 0.0666 + 1
	var idx = 0
	
	# bones
	
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
				var base_rot = 0
				var trans = Vector3(key_data["x"]*0.01, key_data["y"]*0.01, 0)
				var bone_idx = skeleton.find_bone(bone)
				trans = Transform(skeleton.get_bone_rest(bone_idx).basis).affine_inverse() * trans
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
		var track_path = str(root.get_path_to(skeleton)) + ":" + bone
		animation.add_track(Animation.TYPE_TRANSFORM)
		animation.track_set_path(idx, track_path)
		
		for step in range(steps):
			animation.transform_track_insert_key(idx, step*0.0666, transforms[step], quats[step], scales[step])
		idx += 1
	
	for bone in bones:
		var bone_def = bones[bone]
		var orig_path = ".:" + bone_def["name"]
		var orig_idx = animation.find_track(orig_path)
		if orig_idx < 0:
			continue
		if bone_def.has("inheritRotation") && !bone_def["inheritRotation"]:
			print("Fix bone rotation for ", bone)
			while bone_def.has("parent"):
				bone_def = bones[bone_def["parent"]]
				var parent_path = ".:" + bone_def["name"]
				var parent_idx = animation.find_track(parent_path)
				if parent_idx < 0:
					continue
				for key_idx in range(animation.track_get_key_count(parent_idx)):
					var orig_arr = animation.transform_track_interpolate(orig_idx, 0.0666*key_idx)
					var orig_tr = Transform(orig_arr[1])
					var parent_tr = Transform(animation.transform_track_interpolate(parent_idx, 0.0666*key_idx)[1])
					var orig_transformed = Quat(orig_tr.rotated(Vector3(0,0,1), parent_tr.basis.get_euler().z).basis)
					animation.track_remove_key(orig_idx, key_idx)
					animation.transform_track_insert_key(orig_idx, 0.0666*key_idx, orig_arr[0], orig_transformed, orig_arr[2])
				
	for slot_name in slots_data:
		var slot_data = slots_data[slot_name]
		var slot_path = "./" + slot_name.replace("/", "")
		var attachment_data = []
		if slot_data.has("attachment"):
			attachment_data = slot_data["attachment"]
			
		for key_data in attachment_data:
			for attachment_node in skeleton.get_node(slot_path).get_children():
				var attachment_path = str(root.get_path_to(skeleton)) + "/" + slot_path + "/" + attachment_node.get_name() + ":visibility/visible"
				idx = animation.find_track(attachment_path)
				print("add animation for", attachment_path, " track_idx=", idx)
				if idx < 0:
					print("adding track ", attachment_path)
					idx = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(idx, attachment_path)
				var visible = key_data["name"].replace("/", "") == attachment_node.get_name()
				animation.track_insert_key(idx, key_data["time"], visible)

					
					
			
		
		
	for skin_name in deform_data:
		if !import_deform:
			break
		for slot_name in deform_data[skin_name]:
			for attachment_name in deform_data[skin_name][slot_name]:
				if !attachment_binded_to_single_bone(slot_name, attachment_name):
					continue
				var base_path = str(root.get_path_to(skeleton)) + "/" + slot_name + "/" + attachment_name + ":morph/" + animation_name + "_" + skin_name + "_";
				var morph_index = 0
				var keys = deform_data[skin_name][slot_name][attachment_name]
				var last_path = null
				for key_data in keys:
					animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(idx, base_path + str(morph_index))
					for sidx in range(keys.size()):
						for kd in keys:
							if kd["time"] == key_data["time"]:
								animation.track_insert_key(idx, key_data["time"], float(1))
							else:
								animation.track_insert_key(idx, kd["time"], float(0))
					morph_index += 1
					idx += 1
					

	
	player.add_animation(animation_name, animation)
	
	
func detect_animation_time(anim_data):
	var time = 0
	print("keys: ", anim_data.keys(), ", ", data["animations"].keys())
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
	var last_deform = 0
	var deforms = []
	var deform_names = []
	
	func add_vertex(vert):
		if deforms.size():
			var v = Vertex.new()
			v.pos = vert
			v.uv = verts[last_deform].uv
			#v.uv = Vector2()
			deforms[deforms.size()-1].append(v)
			last_deform += 1
			return
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
	func deform(name):
		deforms.append([])
		deform_names.append(name)
		last_deform = 0
	func index():
		var new_verts = []
		var index_map = {}
		indices = IntArray()
		var old_idx = 0
		var new_deforms = []
		for deform in deforms:
			new_deforms.append([])
		for vert in verts:
			var idx
			if !index_map.has(vert.pos):
				idx = index_map.size()
				new_verts.append(vert)
				for deform_idx in range(deforms.size()):
					new_deforms[deform_idx].append(deforms[deform_idx][old_idx])
				index_map[vert.pos] = idx
			else:
				idx = index_map[vert.pos]
			indices.append(idx)
			old_idx += 1
		verts = new_verts
		deforms = new_deforms
			
	func build_mesh():
		var mesh = Mesh.new()
		var vert_array = Vector3Array()
		var uvs_array = Vector2Array()
		var bones_array = FloatArray()
		var weights_array = FloatArray()
		for vert in verts:
			vert_array.append(vert.pos)
			uvs_array.append(vert.uv)
			if vert.bones != null:
				for bone in vert.bones:
					bones_array.append(bone)
			else:
				bones_array = null
			if vert.weights != null:
				for weight in vert.weights:
					weights_array.append(weight)
			else:
				weights_array = null
		
		var deforms_array = []
		for deform in deforms:
			var deform_vert_array = Vector3Array()
			var deform_uv_array = Vector2Array()
			for deform_vert in deform:
				deform_vert_array.append(deform_vert.pos)
				deform_uv_array.append(deform_vert.uv)
			deforms_array.append([
				deform_vert_array,
				null,
				null,
				null,
				deform_uv_array,
				null,
				null,
				null,
				null
			])
			
		for deform_name in deform_names:
			mesh.add_morph_target(deform_name)
		mesh.set_morph_target_mode(0)
			
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
		], deforms_array)
		var aabb = AABB(Vector3(0, 0, -1), Vector3(20,20,5))
		mesh.set_custom_aabb(aabb)
		return mesh
