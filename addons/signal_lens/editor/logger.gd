@tool
extends Control

func _on_open_button_toggled(toggled_on: bool) -> void:
	visible = toggled_on
