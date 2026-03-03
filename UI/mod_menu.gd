extends ColorRect

signal event_triggered(event_name: String)

@onready var container = $VBoxContainer/ScrollContainer/GridContainer

func _ready():
	# For now, we'll just have one placeholder button for the first event
	# In the future, we can add buttons dynamically or manually here
	pass

func _on_btn_event_pressed(event_name: String):
	event_triggered.emit(event_name)
	# Optional: Close menu after triggering?
	# get_parent().toggle_mod_menu() 

signal closed()

func _on_close_button_pressed():
	closed.emit()
