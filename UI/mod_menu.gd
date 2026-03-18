extends ColorRect

signal event_triggered(event_name: String)
signal teleport_requested(position: Vector3)
signal save_position_requested(custom_name: String)

const SAVE_FILE = "user://teleports_custom.json"

@onready var container = $VBoxContainer/ScrollContainer/GridContainer
@onready var btn_save = $VBoxContainer/ScrollContainer/GridContainer/BtnSavePosition
@onready var edit_name = $VBoxContainer/ScrollContainer/GridContainer/EditTeleportName

var custom_teleports = [] # Guardaremos [{name: "Lobby", pos: Vector3}]

func _ready():
	btn_save.pressed.connect(_on_save_pressed)
	
	load_custom_teleports()

func _on_save_pressed():
	var name_text = edit_name.text.strip_edges()
	if name_text == "":
		name_text = "POS_DE_TESTEO"
	save_position_requested.emit(name_text)
	edit_name.text = "" # Limpiar para el siguiente

func add_teleport_button(pos: Vector3, custom_name: String, save: bool = true):
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(hbox)
	
	var btn = Button.new()
	btn.text = "📍 " + custom_name.to_upper()
	btn.custom_minimum_size.y = 35
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 16)
	hbox.add_child(btn)
	btn.pressed.connect(_on_btn_teleport_pressed.bind(pos))
	
	var btn_rename = Button.new()
	btn_rename.text = " ✏️REN "
	btn_rename.custom_minimum_size.y = 35
	btn_rename.add_theme_font_size_override("font_size", 16)
	btn_rename.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	hbox.add_child(btn_rename)
	
	var btn_delete = Button.new()
	btn_delete.text = " ✖BOR "
	btn_delete.custom_minimum_size.y = 35
	btn_delete.add_theme_font_size_override("font_size", 16)
	btn_delete.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	hbox.add_child(btn_delete)
	
	var tp_dict = {"name": custom_name, "x": pos.x, "y": pos.y, "z": pos.z}
	btn_delete.pressed.connect(func(): _delete_teleport(hbox, tp_dict))
	btn_rename.pressed.connect(func(): _rename_teleport(btn, tp_dict))
	
	if save:
		custom_teleports.append(tp_dict)
		save_custom_teleports()

func _rename_teleport(btn_node: Button, tp_dict: Dictionary):
	# Si la barra de texto tiene algo escrito, lo usamos como nuevo nombre
	var new_name = edit_name.text.strip_edges()
	if new_name == "":
		# Por ahora, si no hay texto, no hacemos nada (podríamos mostrar un popup)
		print("Escribe el nuevo nombre en la barra de arriba antes de presionar Renombrar.")
		return
		
	# Actualizar el diccionario y el archivo
	for i in range(custom_teleports.size()):
		var tp = custom_teleports[i]
		if tp.name == tp_dict.name and is_equal_approx(float(tp.x), float(tp_dict.x)) and is_equal_approx(float(tp.y), float(tp_dict.y)) and is_equal_approx(float(tp.z), float(tp_dict.z)):
			custom_teleports[i].name = new_name
			tp_dict.name = new_name # Actualizar la referencia local también
			break
			
	save_custom_teleports()
	
	# Actualizar visualmente el botón
	btn_node.text = "📍 " + new_name.to_upper()
	edit_name.text = "" # Limpiar la caja de texto

func _delete_teleport(node_to_remove: Node, tp_dict: Dictionary):
	for i in range(custom_teleports.size()):
		var tp = custom_teleports[i]
		var eq_name = (tp.name == tp_dict.name)
		var eq_x = is_equal_approx(float(tp.x), float(tp_dict.x))
		var eq_y = is_equal_approx(float(tp.y), float(tp_dict.y))
		var eq_z = is_equal_approx(float(tp.z), float(tp_dict.z))
		
		if eq_name and eq_x and eq_y and eq_z:
			custom_teleports.remove_at(i)
			break
	save_custom_teleports()
	node_to_remove.queue_free()

func save_custom_teleports():
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(custom_teleports)
		file.store_string(json_string)
		file.close()

func load_custom_teleports():
	if not FileAccess.file_exists(SAVE_FILE):
		return
		
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			custom_teleports = json.data
			for tp in custom_teleports:
				var pos = Vector3(tp.x, tp.y, tp.z)
				add_teleport_button(pos, tp.name, false)

func _on_btn_event_pressed(event_name: String):
	event_triggered.emit(event_name)

func _on_btn_teleport_pressed(pos: Vector3):
	teleport_requested.emit(pos)

signal closed()

func _on_close_button_pressed():
	closed.emit()
