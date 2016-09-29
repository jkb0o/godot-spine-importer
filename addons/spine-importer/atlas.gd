tool
extends Reference

const NiggaTexture = preload("nigga_texture.gd")
# member variables here, example:
# var a=2
# var b="textvar"

var basedir = ""
var source = ""
var settings = {}
var children = {}

func get_child_rect(key):
	var child = children[key]
	var xy = child['xy'].split(',')
	var size = child['size'].split(',')
	var width = size[0]
	var height = size[1]
	if get_child_rotate(key):
		width = size[1]
		height = size[0]
	
	return Rect2(xy[0], xy[1], width, height)

func get_child_rotate(key):
	var child = children[key]
	return child['rotate'] == 'true'
	
func save(target_dir):
	var interfix = ''
	if !target_dir.ends_with('/'):
		interfix = '/'

	var prefix = source.split('.')[0]
	for key in children.keys():
		var atlas_texture = NiggaTexture.new()
		atlas_texture.set_atlas(load(basedir + '/' + source))
		atlas_texture.set_region(get_child_rect(key))
		atlas_texture.rotate = get_child_rotate(key)
		var child_dir = target_dir + interfix + prefix + '/'
		Directory.new().make_dir_recursive(child_dir)
		var path = child_dir + key + '.xml'
		
		var d = Directory.new()
		d.make_dir_recursive(path.get_base_dir())
		print("Saving atlas to ", path)
		ResourceSaver.save(path, atlas_texture)
