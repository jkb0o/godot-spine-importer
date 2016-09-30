tool
extends EditorPlugin

var importer = preload("import_dialog.tscn").instance()

func _ready():
	add_control_to_bottom_panel(importer, "Spine")
	
func _exit_tree():
	remove_control_from_bottom_panel(importer)


