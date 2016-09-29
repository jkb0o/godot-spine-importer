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


