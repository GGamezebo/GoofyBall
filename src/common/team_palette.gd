class_name TeamPalette
extends Resource

## Team colors (concept/art-direction.md): A cyan, B magenta, C lime, D orange.

@export var colors: Array[Color] = [
	Color("#03B8FF"), Color("#FF05AD"), Color("#7CFF4F"), Color("#FF8A1F"),
]
@export var names: Array[String] = ["Синий", "Розовый", "Зелёный", "Оранжевый"]


func color(team: int) -> Color:
	return colors[team % colors.size()]


func team_name(team: int) -> String:
	return names[team % names.size()]
