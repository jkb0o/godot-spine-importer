tool
extends HBoxContainer

export var label = "Import from:"
export (int, "Open File", "Open Files", "Open Dir", "Open Any", "Save File") var mode = 0
export (int, "Resources", "User Data", "Filesystem") var access = 0
export var filter = "*"

signal selected

var target_dir = null
var selected = null
var dialog

func _ready():
	get_node("label").set_text(label)
	get_node("button").connect("pressed", self, "open_dialog")
	
func open_dialog():
	dialog = FileDialog.new()
	dialog.set_size(Vector2(800, 600))
	get_node("/root/EditorNode").add_child(dialog)
	dialog.set_access(access)
	dialog.set_mode(mode)
	for f in filter.split(","):
		dialog.add_filter(f.strip_edges())
	dialog.connect("file_selected", self, "on_selected")
	dialog.connect("files_selected", self, "on_selected")
	dialog.connect("dir_selected", self, "on_selected")
	dialog.connect("popup_hide", dialog, "queue_free")
	if target_dir:
		print("Setting current dir to ", target_dir)
		dialog.set_current_dir(target_dir)
	dialog.popup_centered()
	
	
func on_selected(data):
	dialog.queue_free()
	selected = data
	if typeof(selected) == TYPE_STRING:
		target_dir = selected.get_base_dir()
		get_node("edit").set_text(selected)
	elif typeof(selected) == TYPE_STRING_ARRAY || typeof(selected) == TYPE_ARRAY:
		target_dir = selected[0].get_base_dir()
		var text = ""
		for idx in range(selected.size()):
			text += selected[idx]
			if idx < selected.size()-1:
				text += ", "
		get_node("edit").set_text(text)
	print("emitting selected")
	emit_signal("selected")


