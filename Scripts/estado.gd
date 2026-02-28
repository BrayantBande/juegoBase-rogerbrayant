extends Node
class_name Estado # Esto nos permite usarlo como base para los demás

# Señal para avisarle a la Máquina de Estados que queremos cambiar
signal transicion_solicitada(estado_actual, nuevo_estado_nombre)

var enemigo: CharacterBody3D # Referencia al cuerpo del monstruo

# Se ejecuta al entrar a este estado
func entrar():
	pass

# Se ejecuta al salir de este estado
func salir():
	pass

# Es como el _process normal
func actualizar(_delta: float):
	pass

# Es como el _physics_process normal
func actualizar_fisica(_delta: float):
	pass
