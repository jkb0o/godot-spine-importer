# ************************************************************************
# atlas_reader.gd
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
extends Reference

var basedir = ""
var target_dir = ""
var current_atlas
var current_texture
var current_image

func from(resource_path, p_target_dir):
	basedir = resource_path.get_base_dir()
	target_dir = p_target_dir
	var f = File.new()
	f.open(resource_path, File.READ)
	return parse(f)

func get_next_line(file):
	var line = file.get_line()
	while (line == "" and !file.eof_reached()):
		line = file.get_line()
	return line

func parse(file):
	var atlases = []
	current_atlas = {}
	current_texture = null
	while (!file.eof_reached()):
		var line = file.get_line()
		if (line == ""):
			if current_atlas != null:
				atlases.append(current_atlas)
			
			current_image = null
			var d = Directory.new()
			var filename = get_next_line(file)
			if !filename.strip_edges():
				continue
			var target_filename = target_dir + "/" + filename
			if !d.dir_exists(target_filename.get_base_dir()):
				d.make_dir_recursive(target_filename.get_base_dir())
			print("Saving atlas page to ", target_filename)
			d.copy(basedir + "/" + filename, target_filename)
			current_texture = load(target_filename)
		
		var splitted = line.split(':') 
		if (splitted.size() > 1):
			var key = splitted[0].strip_edges()
			var value = splitted[1].strip_edges()
			if current_image != null and current_image != "":
				current_atlas[current_image][key] = value
			else:
				# pass settings
				#current_atlas.settings[key] = value
				pass
		else:
			var img = splitted[0].strip_edges()
			if img != null and img != "":
				current_image = img
				print("Found image ", img)
				current_atlas[img] = {"texture":current_texture}
	
	var images = {}
	for atlas in atlases:
		for img_name in atlas:
			var img_data = atlas[img_name]
			var img = AtlasImage.new()
			img.rect = get_rect(img_data)
			img.rotate = get_rotate(img_data)
			img.texture = img_data["texture"]
			img.name = img_name
			images[img_name] = img
			
	return images
	
func get_rect(data):
	var xy = data['xy'].split(',')
	var size = data['size'].split(',')
	var width = size[0]
	var height = size[1]
	if get_rotate(data):
		width = size[1]
		height = size[0]
	return Rect2(xy[0], xy[1], width, height)

func get_rotate(data):
	return data['rotate'] == 'true'

static func import(atlas_path, target_path):
	var atlas_reader = new()
	print("Importing atlas ", atlas_path, " => ", target_path)
	return atlas_reader.from(atlas_path, target_path)
	
class AtlasImage:
	extends Reference
	
	var name = "unnamed"
	var rect = Rect2()
	var texture = null
	var rotate = false

