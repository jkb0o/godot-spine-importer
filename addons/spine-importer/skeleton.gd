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
extends Skeleton


export var bind_bones = IntArray()
export var bind_nodes = StringArray()

func _ready():
	for idx in range(bind_bones.size()):
		.bind_child_node_to_bone(bind_bones[idx], get_node(bind_nodes[idx]))
	
func bind_child_node_to_bone(bone_idx, node):
	bind_bones.append(bone_idx)
	bind_nodes.append(str(get_path_to(node)))
	.bind_child_node_to_bone(bone_idx, node)


