extends Control

signal cerrar_opciones

@onready var check_fullscreen = $VBoxContainer/HBoxContainer/CheckFullscreen
@onready var slider_sens_x = $VBoxContainer/SensXContainer/SliderSensX
@onready var label_sens_x = $VBoxContainer/SensXContainer/LabelSensX
@onready var slider_sens_y = $VBoxContainer/SensYContainer/SliderSensY
@onready var label_sens_y = $VBoxContainer/SensYContainer/LabelSensY

const SETTINGS_FILE = "user://game_settings.json"

func _ready() -> void:
	# Ajustar el botón al estado actual de la ventana
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		check_fullscreen.set_pressed_no_signal(true)
	else:
		check_fullscreen.set_pressed_no_signal(false)
		
	# Cargar opciones guardadas
	load_settings()

func load_settings():
	var sens_x = 4.0
	var sens_y = 4.0
	
	if FileAccess.file_exists(SETTINGS_FILE):
		var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		var dict = JSON.parse_string(file.get_as_text())
		file.close()
		if dict != null and typeof(dict) == TYPE_DICTIONARY:
			if dict.has("sensibilidad_ui_x"): sens_x = dict["sensibilidad_ui_x"]
			if dict.has("sensibilidad_ui_y"): sens_y = dict["sensibilidad_ui_y"]
			
	slider_sens_x.set_value_no_signal(sens_x)
	slider_sens_y.set_value_no_signal(sens_y)
	_actualizar_labels(sens_x, sens_y)

func save_settings():
	var dict = {
		"sensibilidad_ui_x": slider_sens_x.value,
		"sensibilidad_ui_y": slider_sens_y.value
	}
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(dict))
		file.close()

func _actualizar_labels(sx: float, sy: float):
	label_sens_x.text = "Sensibilidad X: " + str(int(sx))
	label_sens_y.text = "Sensibilidad Y: " + str(int(sy))

func _on_check_fullscreen_toggled(toggled_on: bool) -> void:
	# Evitar error si se está probando dentro de una ventana incrustada del editor
	if get_window().is_embedded():
		print("NOTA: El modo pantalla completa no funciona mientras el juego está incrustado en el editor.")
		print("¡Pero funcionará perfectamente cuando exportes el juego!")
		return

	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_slider_sens_x_value_changed(value: float) -> void:
	_actualizar_labels(value, slider_sens_y.value)
	save_settings()
	_update_player_sensitivity()

func _on_slider_sens_y_value_changed(value: float) -> void:
	_actualizar_labels(slider_sens_x.value, value)
	save_settings()
	_update_player_sensitivity()

func _update_player_sensitivity():
	var player = get_tree().get_first_node_in_group("jugador")
	if player and player.has_method("aplicar_sensibilidad"):
		player.aplicar_sensibilidad(slider_sens_x.value * 0.00075, slider_sens_y.value * 0.00075)

func _on_btn_volver_pressed() -> void:
	emit_signal("cerrar_opciones")
