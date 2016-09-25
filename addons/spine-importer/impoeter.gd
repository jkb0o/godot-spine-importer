tool
extends Control


func _ready():
	get_node("button").connect("pressed", self, "import")
	
	
func import():
	pass


