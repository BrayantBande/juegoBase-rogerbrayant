extends Control

signal cerrar_opciones

@onready var check_fullscreen = $VBoxContainer/HBoxContainer/CheckFullscreen

func _ready() -> void:
	# Ajustar el botón al estado actual de la ventana
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		check_fullscreen.set_pressed_no_signal(true)
	else:
		check_fullscreen.set_pressed_no_signal(false)

func _on_check_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		get_window().mode = Window.MODE_WINDOWED

func _on_btn_volver_pressed() -> void:
	emit_signal("cerrar_opciones")
