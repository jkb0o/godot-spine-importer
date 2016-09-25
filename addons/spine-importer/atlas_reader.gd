tool
extends Reference

const Atlas = preload("atlas.gd")

# member variables here, example:
# var a=2
# var b="textvar"
var atlases = []
var basedir = ""

func from(resource_path):
	atlases = []
	basedir = resource_path.get_base_dir()
	var f = File.new()
	f.open(resource_path, File.READ)
	parse(f)
	return atlases

func to(data, indent=0):
	var prefix = ""
	for i in range(indent):
		prefix += " "
	
	if typeof(data) != TYPE_DICTIONARY:
		print(prefix + str(data))
	else:
		for key in data.keys():
			print(prefix + key)
			to(data[key], indent + 2)

func get_next_line(file):
	var line = file.get_line()
	while (line == "" and !file.eof_reached()):
		line = file.get_line()
	return line

func parse(file):
	var current_atlas = null
	var current_path = null
	while (!file.eof_reached()):
		var line = file.get_line()
		if (line == ""):
			if current_atlas != null:
				atlases.append(current_atlas)
			
			current_path = null
			current_atlas = Atlas.new()
			current_atlas.source = get_next_line(file)
			current_atlas.basedir = basedir
		
		var splitted = line.split(':') 
		if (splitted.size() > 1):
			var key = splitted[0].strip_edges()
			var value = splitted[1].strip_edges()
			if current_path != null and current_path != "":
				current_atlas.children[current_path][key] = value
			else:
				current_atlas.settings[key] = value
		else:
			var new_path = splitted[0].strip_edges()
			if new_path != null and new_path != "":
				current_path = splitted[0].strip_edges()
				current_atlas.children[current_path] = {}
	
	if (
		current_atlas.source != null and 
		current_atlas.source.length() > 0
	):
		atlases.append(current_atlas)
	return atlases

static func import(atlas_path, target_path):
	var atlas_reader = new()
	var atlases = atlas_reader.from(atlas_path)
	for atlas in atlases:
		atlas.save(target_path)
	