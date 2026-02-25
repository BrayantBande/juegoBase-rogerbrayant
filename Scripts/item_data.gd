extends Resource
class_name ItemData

# Las 3 categorías estilo Dark Souls
enum TipoItem { CLAVE, CONSUMIBLE, NOTA }

@export var id_item: String = ""
@export var nombre_item: String = ""
@export_multiline var descripcion: String = ""
@export var tipo: TipoItem = TipoItem.CONSUMIBLE
@export var icono: Texture2D
