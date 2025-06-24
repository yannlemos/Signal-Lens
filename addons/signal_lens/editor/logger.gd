@tool
extends Control

@export var log_container: Control
@export var copy_button: Button
@export var clear_button: Button
@export var v_split_container: VSplitContainer
@export var h_split_container: HSplitContainer

var _logs: Array[String]

var _starting_v_split_margin_end: int
var _starting_h_split_offset: int

func _ready() -> void:
	copy_button.icon = EditorInterface.get_base_control().get_theme_icon("ActionCopy", "EditorIcons")
	clear_button.icon = EditorInterface.get_base_control().get_theme_icon("Clear", "EditorIcons")
	_starting_v_split_margin_end = v_split_container.drag_area_margin_end
	_starting_h_split_offset = h_split_container.split_offset
	
func clear_log():
	_logs.clear()
	for child in log_container.get_children():
		child.queue_free()

func create_log(datetime: String, timestamp: String, node_name: String, signal_name: String):
	var raw_log = "%s | %s\n%s → %s" % [datetime, timestamp, node_name, signal_name]
	_logs.append(raw_log)
	
	var pretty_log: String = ""
	
	pretty_log += "[font_size=12]"
	pretty_log += "[color=WEB_GRAY] %s | %s [/color] \n" % [datetime, timestamp]
	pretty_log += "[color=WHITE] %s → %s" % [node_name, signal_name]
	
	var log_label: RichTextLabel = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = true
	log_label.selection_enabled = true
	log_label.add_theme_constant_override("line_separation", 5)
	log_label.context_menu_enabled = true
	log_label.text = pretty_log
	log_label.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	log_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())

	log_container.add_child(log_label)


func _on_clear_button_pressed() -> void:
	clear_log()


func _on_copy_to_clipboard_button_pressed() -> void:
	var result: String
	var index = 0
	for pretty_log: String in _logs:
		result += pretty_log
		index += 1
		if index < _logs.size():
			result += "\n\n"
	DisplayServer.clipboard_set(result)


func _on_visibility_changed() -> void:
	if visible:
		create_log("2025-06-24T14:56:45", "00:00:03:755", "NodeTest", "node_tested")


var _last_offset: int = 0

func _on_h_split_container_dragged(offset: int) -> void:
	var h_split_offset_progress = inverse_lerp(_starting_h_split_offset, 0, offset)
	var new_v_split_drag_area = lerp(_starting_v_split_margin_end, 0, h_split_offset_progress)
	v_split_container.drag_area_margin_end = new_v_split_drag_area
	#if offset == _last_offset: return
	#if offset > _last_offset:
		#v_split_container.drag_area_margin_end -= 2
	#else:
		#v_split_container.drag_area_margin_end += 2
	#_last_offset = offset
