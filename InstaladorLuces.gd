@tool
extends EditorScript

# LA MAGIA AVANZADA: Instalador capaz de repartir dos lámparas diferentes a la misma vez

# 1. LISTA MÁXIMA PROHIBICIÓN: Cuartos que se quedan vacíos hasta nuevo aviso (para su propia luz)
const IGNORAR_TOTALMENTE = ["Morgue"]

# 2. LISTA LUZ 2 (CILINDRO): Cuartos que llevarán el nuevo cilindro especial.
const CUARTOS_NUEVA_LUZ = ["Oficina", "Radiografia", "Radiografía", "Pediatra", "Pediatría", "H1", "H2", "H3", "H4", "HJ", "Habitacion", "Habitación"]

# NOTA: ¡Todo lo que NO esté en la lista 1 ni en la 2, llevará la LUZ GENERAL (tubo) por defecto!
# (Por ejemplo: Entrada, Baños, Pasillos, etc).
const TEXTO_A_BUSCAR = "Luz"

func _run():
	var escena_actual = get_scene()
	if not escena_actual:
		print("❌ Error: Tienes que tener activa la escena Hospital.tscn en el centro.")
		return
		
	# Cargamos los dos modelos de luz listos para la acción
	var modelo_luz_1 = load("res://assets/Modelos/Luces/Luz1/LuzGeneralHospital.tscn")
	var modelo_luz_2 = load("res://assets/Modelos/Luces/Luz2/LuzSecundaria.tscn")
	
	if not modelo_luz_1 or not modelo_luz_2:
		print("❌ Error: No se pudo cargar alguno de los archivos .tscn de las luces.")
		return
		
	var cont_grales = 0
	var cont_especiales = 0
	var cont_ignorados = 0
	
	# Buscamos absolutamente todas las flechas
	var nodos = escena_actual.find_children("*" + TEXTO_A_BUSCAR + "*", "Node3D", true, false)
	
	if nodos.size() == 0:
		print("⚠️ No encontré flechas. Asegúrate de estar en el Hospital.tscn original limpiecito.")
		return
		
	for nodo in nodos:
		var nombre = nodo.name.to_lower()
		
		# ¿Pertenece a la lista de ignorados totales? (Morgue)
		var prohibida = false
		for omitir in IGNORAR_TOTALMENTE:
			if omitir.to_lower() in nombre:
				prohibida = true
				break
				
		if prohibida:
			cont_ignorados += 1
			continue 
			
		# ¿Pertenece a las nuevas luces especiales? (Habitaciones, Oficinas)
		var es_luz2 = false
		for cuarto in CUARTOS_NUEVA_LUZ:
			if cuarto.to_lower() in nombre:
				es_luz2 = true
				break
				
		# Elegimos qué lámpara usar para esta flecha
		var nueva_luz
		if es_luz2:
			nueva_luz = modelo_luz_2.instantiate()
			cont_especiales += 1
		else:
			nueva_luz = modelo_luz_1.instantiate()
			cont_grales += 1
			
		nodo.get_parent().add_child(nueva_luz)
		
		# Ajuste posicional exacto para todas
		nueva_luz.global_transform = nodo.global_transform
		nueva_luz.rotate_x(deg_to_rad(180)) 
		
		# Ajustes personalizados según la lámpara
		if es_luz2:
			# Cilindro (Luz 2)
			nueva_luz.global_position.y -= 0.15   # Cambia este valor si quedó muy alto/bajo
			nueva_luz.scale = Vector3(0.8, 0.8, 0.8) # Las redujimos porque 1.2 era enorme
		else:
			# Tubo fluorescente (Luz 1)
			nueva_luz.global_position.y -= 0.10 
			nueva_luz.scale = Vector3(1.5, 1.5, 1.5) # La escala que aprobamos antes
		
		nueva_luz.owner = escena_actual
		nodo.queue_free()
		
	print("✅ ¡HOSPITAL TOTALMENTE ILUMINADO! ------------------")
	print("🔦 ", cont_grales, " luces del Tubo General (Baños, Pasillos, Entrada)")
	print("🔮 ", cont_especiales, " luces de Cilindro (Oficinas, Habitaciones)")
	print("❌ ", cont_ignorados, " flechas intactas para futuros cuartos (Morgue)")
