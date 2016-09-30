# ************************************************************************
# import_dialog .gd
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
extends VBoxContainer

onready var atlas = get_node("atlas")
onready var json = get_node("json")
onready var target = get_node("target")

func _ready():
	atlas.connect("selected", self, "atlas_selected")
	json.connect("selected", self, "json_selected")
	get_node("button").connect("pressed", self, "process_import")
	
func atlas_selected():
	print("atlas selected")
	json.target_dir = atlas.selected.get_base_dir()
	
func json_selected():
	print("json selected")
	var json_dir
	if typeof(json.selected) == TYPE_STRING:
		json_dir = json.selected.get_base_dir()
	else:
		json_dir = json.selected[0].get_base_dir()
	atlas.target_dir = json_dir
	
func process_import():
	var f = File.new()
	var d = Directory.new()
	if !atlas.selected || !f.file_exists(atlas.selected):
		return warn("No atlas selected")
	if json.selected == null:
		return warn("No json selected")
	for json_file in json.selected:
		if !f.file_exists(json_file):
			return warn("Bad json_file: " + json_file)
	if !target.selected || !target.selected.begins_with("res://") || !d.dir_exists(target.selected):
		return warn("Invalid target path")
		
	var importer = preload("importer.gd").new()
	importer.atlas_path = atlas.selected
	importer.json_pathes = json.selected
	importer.target_path = target.selected
	add_child(importer)
	importer.import()
	importer.queue_free()
	

func warn(message):
	var warn = AcceptDialog.new()
	get_node("/root/EditorNode").add_child(warn)
	warn.set_title("Import error")
	warn.set_size(Vector2(400, 300))
	warn.set_text(message)
	warn.connect("popup_hide", warn, "queue_free")
	warn.popup_centered()
	
