@tool
class_name SignalLensLogger
extends Control

const MAX_LOGS := 1000

enum Options {
	DATETIME,
	TIMESTAMP,
	PROCESS_FRAME,
	PHYSICS_FRAME
}

@export var log_container: Control
@export var copy_button: Button
@export var clear_button: Button
@export var v_split_container: VSplitContainer
@export var h_split_container: HSplitContainer
@export var log_scroll: ScrollContainer
@export var counter_label: Label

var _logs: Array[String]

var _starting_v_split_margin_end: int
var _starting_h_split_offset: int

var _options_popup: PopupMenu

func _ready() -> void:
	copy_button.icon = EditorInterface.get_base_control().get_theme_icon("ActionCopy", "EditorIcons")
	clear_button.icon = EditorInterface.get_base_control().get_theme_icon("Clear", "EditorIcons")
	_starting_v_split_margin_end = v_split_container.drag_area_margin_end
	_starting_h_split_offset = h_split_container.split_offset
	counter_label.text = ""
	
func clear():
	_logs.clear()
	for child in log_container.get_children():
		child.queue_free()
	counter_label.text = ""

func create_log(datetime: String, timestamp: String, node_name: String, signal_name: String, signal_arguments: Array, process_frames: int, physics_frames: int):
	if _logs.size() >= MAX_LOGS:
		_logs.pop_front()
		log_container.get_child(0).queue_free()
	
	var raw_log = "%s | %s\n%s | %s\n%s → %s" % [datetime, timestamp, process_frames, physics_frames, node_name, signal_name]
	if not signal_arguments.is_empty(): raw_log += "\n" + str(signal_arguments)
	_logs.append(raw_log)
	
	var pretty_log: String = ""
	
	pretty_log += "[font_size=12]"
	pretty_log += "[color=WEB_GRAY]%s | %s\nProcess: %s | Physics: %s[/color]\n" % [datetime, timestamp, process_frames, physics_frames]
	pretty_log += "[font_size=13][color=WHITE][b]%s → %s[/b]\n" % [node_name, signal_name]
	if not signal_arguments.is_empty(): pretty_log += "[color=WHITE]" + str(signal_arguments)
	
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
	await get_tree().process_frame
	log_scroll.scroll_vertical = log_scroll.get_v_scroll_bar().max_value
	
	counter_label.text = "(%s)" % [str(_logs.size())]
	
func _on_clear_button_pressed() -> void:
	clear()


func _on_copy_button_pressed() -> void:
	var result: String
	var index = 0
	for pretty_log: String in _logs:
		result += pretty_log
		index += 1
		if index < _logs.size():
			result += "\n\n"
	DisplayServer.clipboard_set(result)


func _on_h_split_container_dragged(offset: int) -> void:
	var h_split_offset_progress = inverse_lerp(_starting_h_split_offset, 0, offset)
	var new_v_split_drag_area = lerp(_starting_v_split_margin_end, 0, h_split_offset_progress)
	v_split_container.drag_area_margin_end = new_v_split_drag_area
