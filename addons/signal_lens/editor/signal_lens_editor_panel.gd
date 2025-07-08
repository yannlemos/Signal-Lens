## Draw's Signal Lens panel in the debugger bottom tab inside Godot's editor
## Parses data received from the runtime autoload into
## a user-friendly graph of a node's signal and its connections
@tool
class_name SignalLensEditorPanel
extends Control

## Written in the panel's line edit if nothing is selected and a debugger
## session is active
const TUTORIAL_TEXT: String = "Select a node in the remote scene"

## Default duration a signal emission pulse in seconds
## TODO: This could be a user setting
const DEFAULT_EMISSION_DURATION: float = 1.0

## Default opacity of a connection line in the graph when rendered
## TODO: This could be a user setting
const DEFAULT_CONNECTION_OPACITY: float = 0.3

## This enum is used to set up the graph node's ports 
## in a way that provides more legibility in the code
enum Direction {LEFT, RIGHT}

## This enum keeps available option IDs
enum Options {
	HIDE_SIGNALS_WITHOUT_CONNECTIONS,
	HIDE_BUILT_IN_SIGNALS,
	SHOW_GRAPH_TOOLBAR,
	SHOW_GRAPH_MINIMAP
}

## Emitted on user pressed "refresh" button
signal node_data_requested(node_path)

## Current node path being inspected
var current_node: NodePath = ""

## If true, ignores new incoming data from the remote tree
## effectively locking the panel current node path
var block_new_inspections: bool = false

## If true, all incoming signal emissions will be drawn and won't fade out
var keep_emissions: bool = false

## Multiplier that increases or decreases emission drawing speed 
## Acquired from slider in scene
var emission_speed_multiplier: float = 1.0

var connection_opacity: float = DEFAULT_CONNECTION_OPACITY

## Array that collects active pulse connections so that they can be
## all cleanup together when unfreezing emissions
var pulsing_connections: Array = []

## Value of options
var settings: Dictionary = {
	Options.HIDE_SIGNALS_WITHOUT_CONNECTIONS: true,
	Options.HIDE_BUILT_IN_SIGNALS: false,
	Options.SHOW_GRAPH_TOOLBAR: false,
	Options.SHOW_GRAPH_MINIMAP: false
}

# Scene references
@export var graph_edit: GraphEdit 
@export var logger_button: Button
@export var node_path_line_edit: LineEdit 
@export var refresh_button: Button 
@export var options_button: MenuButton
@onready var options_popup: PopupMenu = options_button.get_popup()
@export var clear_button: Button
@export var inactive_text: Label
@export var warning_text: Label
@export var pin_checkbox: CheckButton
@export var keep_emissions_checkbox: CheckButton
@export var emission_speed_slider: Slider
@export var emission_speed_icon: Button
@export var connection_opacity_icon: Button
@export var logger: Control

## Initialize panel: Load icons
func _ready() -> void:
	_get_parent_editor_split()
	options_button.icon = EditorInterface.get_base_control().get_theme_icon("GuiTabMenuHl", "EditorIcons")
	clear_button.icon = EditorInterface.get_base_control().get_theme_icon("Clear", "EditorIcons")
	refresh_button.icon = EditorInterface.get_base_control().get_theme_icon("Reload", "EditorIcons")
	pin_checkbox.icon = EditorInterface.get_base_control().get_theme_icon("Pin", "EditorIcons")
	keep_emissions_checkbox.icon = EditorInterface.get_base_control().get_theme_icon("Override", "EditorIcons")
	emission_speed_icon.icon = EditorInterface.get_base_control().get_theme_icon("Timer", "EditorIcons")
	logger_button.icon = EditorInterface.get_base_control().get_theme_icon("FileList", "EditorIcons")
	options_popup.index_pressed.connect(_on_options_index_pressed) # NOTE: ID & index must have same value!
	connection_opacity_icon.icon = EditorInterface.get_base_control().get_theme_icon("GuiVisibilityVisible", "EditorIcons")
	#main_buttons_container.reparent(graph_edit.get_menu_hbox())
	#graph_edit.get_menu_hbox().move_child(main_buttons_container, 0)
	#graph_edit.get_menu_hbox().custom_minimum_size.x = graph_edit.size.x
	graph_edit.get_menu_hbox().reparent(panel_container)
	graph_edit.get_menu_hbox().hide()
	#graph_edit.get_menu_hbox().hide()
	repo_button.icon = EditorInterface.get_base_control().get_theme_icon("ExternalLink", "EditorIcons")
	
@onready var repo_button: Button = $EditorPanel/MainButtonsContainer/HBoxContainer2/RepoButton

@onready var panel_container: PanelContainer = $EditorPanel/PanelContainer
@onready var main_buttons_container: MarginContainer = $EditorPanel/MainButtonsContainer

## Requests inspection of [param current_node] in remote scene
func request_node_data():
	node_data_requested.emit(current_node)

## Receives node signal data from remote scene
## Data structure is detailed further below
func receive_node_data(data: Array):
	draw_node_data(data)

## Sets up editor on project play
func start_session():
	clear_graph()
	pin_checkbox.button_pressed = false
	keep_emissions_checkbox.button_pressed = false
	emission_speed_slider.editable = true
	emission_speed_icon.disabled = false
	node_path_line_edit.text = TUTORIAL_TEXT
	inactive_text.hide()


## Cleans up editor on project stop
func stop_session():
	clear_graph()
	pin_checkbox.disabled = true
	keep_emissions_checkbox.disabled = true
	refresh_button.disabled = true
	clear_button.disabled = true
	emission_speed_slider.editable = false
	emission_speed_icon.disabled = true
	node_path_line_edit.text = ""
	pin_checkbox.button_pressed = false
	keep_emissions_checkbox.button_pressed = false
	inactive_text.show()
	warning_text.hide()
	warning_text.text = ""


## Assigns a [param target_node] to internal member [param current_node]
func assign_node_path(target_node: NodePath):
	# If locked button is toggled, don't change the current node
	if block_new_inspections: return
	
	# If incoming node is invalid, disable refreshing to avoid null nodes
	refresh_button.disabled = target_node.is_empty()
	
	# Assign incoming node as the current one
	current_node = target_node
	
	# Update line edit
	node_path_line_edit.text = current_node
	node_path_line_edit.caret_column = node_path_line_edit.text.length()

#region Graph Rendering

## Clears all nodes from the debugger panel
## Called on user inspecting new node or on play/quit current
## debug session
func clear_graph():
	# If nothing in graph, return
	if graph_edit.get_child_count() == 0: return
	# Not clearing connection activity can lead to unwanted behaviour
	# So this function must be called here for now
	clean_connection_activity()
	# Frees child nodes
	for child: Node in graph_edit.get_children():
		# This seems to be necessary as per Godot 4.3 
		# because this child, despite being internal,
		# is iterated in get_children() and if it is
		# destroyed, the editor crashed
		# so let's ignore it and move on
		if child.name == "_connection_layer": continue
		child.free()
	## Necessary for the minimap to update, it seems
	if graph_edit.minimap_enabled:
		graph_edit.minimap_enabled = false
		graph_edit.minimap_enabled = true

## Draws data received from the runtime autoload
## The data is packages in the following structure:
## Pseudo-code: [Name of target node, [All of the node's signals and each signal's respective callables], Class of target node]
## Print result: [{&"name_of_targeted_node", [{"signal": "item_rect_changed", "callables": [{ "object_name": &"Control", "callable_method": "Control::_size_changed"}], "Control"]
## Is is parsed and drawin into nodes, with connections established between signals and their callables
func draw_node_data(data: Array):
	# If lock button toggled on, don't draw incoming data
	if block_new_inspections: return
	
	# Clear graph to avoid drawing over old data
	clear_graph()
	logger.clear()
	
	# This line is super important to avoid random rendering errors
	# It seems we need to give a small breathing room for the graph edit
	# to fully cleanup, otherwise, artifacts from a previously rendered
	# graph edit may appear and mess up the new drawing
	await get_tree().create_timer(0.1).timeout
	
	# Retrieve the targeted node from the data array, which is always index 0
	var target_node_name = data[0]
	
	# Handle root node inspection edge case
	if target_node_name == "Root":
		warning_text.show()
		warning_text.text = "Root node inspection is not supported."
		return
	else:
		warning_text.hide()

	# Retrieve the targeted node signal data, which is always index 1
	var target_node_signal_data: Array = data[1]
	
	# Create main node from which connections will be created
	# and add it to the graph
	var target_node: SignalLensGraphNode = create_node(target_node_name, "(Signals)")
	graph_edit.add_child(target_node)
	
	var current_signal_index = 0
	
	# Start iterating signal by signal
	for signal_data in target_node_signal_data:
		# Check signal connections and skip not connected signals (based on settings)
		if settings[Options.HIDE_SIGNALS_WITHOUT_CONNECTIONS] and signal_data["callables"].size() == 0: continue
		
		# Check signal connections and skip if signal is built-in (based on settings)
		if settings[Options.HIDE_BUILT_IN_SIGNALS]:
			var class_signals: Array = []
			for class_signal in ClassDB.class_get_signal_list(data[2]):
				class_signals.append(class_signal["name"])
			if signal_data["signal"] in class_signals:
				continue
		
		# Get the color based on the index so we can have the rainbow vibes
		var slot_color = get_slot_color(current_signal_index, target_node_signal_data.size())
		
		# Create the slot button with the signal's name
		create_button_slot(signal_data["signal"], target_node, Direction.RIGHT, slot_color)
		
		# Start iterating each callable in the signal
		var callables_for_current_signal = signal_data["callables"]
		for callable_index in range(callables_for_current_signal.size()):
			var object_name: String = callables_for_current_signal[callable_index]["object_name"]
			var callable_method: String = callables_for_current_signal[callable_index]["method_name"]
			# If a node has already been created for the object that owns the callable
			# Then we don't create an entirely new node
			# Otherwise, we create a new node
			if graph_edit.has_node(object_name):
				var callable_node = graph_edit.get_node(object_name)
				# If callable's object is the same as signal's
				# It means that the target node listens to it's own signals
				# So we create a new node to avoid confusion and keep everything legible
				# for the user
				# Otherwise, we just add a new button to an already existing node
				if callable_node.name == target_node.name:
					var target_callables_node
					if !graph_edit.has_node(target_node_name + " (Callables)"):
						target_callables_node = create_node(target_node_name + " (Callables)")
						graph_edit.add_child(target_callables_node)
						target_callables_node.position_offset += Vector2(250, 0)
					else:
						target_callables_node = graph_edit.get_node(target_node_name + " (Callables)")
					create_button_slot(callable_method, target_callables_node, Direction.LEFT, slot_color)
					graph_edit.connect_node(target_node.name, current_signal_index, target_callables_node.name, target_callables_node.get_child_count() - 1)
				else:
					create_button_slot(callable_method, callable_node, Direction.LEFT, slot_color)
					graph_edit.connect_node(target_node.name, current_signal_index, callable_node.name, callable_node.get_child_count() - 1)
			else:
				var callable_node: SignalLensGraphNode = create_node(object_name, "(Callables)")
				create_button_slot(callable_method, callable_node, Direction.LEFT, slot_color)
				graph_edit.add_child(callable_node)
				# We set the offsets here to se can have the descending stair effect in the resulting graph
				# TODO: This could be a user setting
				callable_node.position_offset += Vector2(callable_node.get_index() * 250, callable_node.get_index() * 50)
				graph_edit.connect_node(target_node.name, current_signal_index, callable_node.name, callable_node.get_child_count() - 1)
		# Finally, we add to the current iterator and move on to the next signal
		current_signal_index += 1
	# Manage button states
	# This is important to make sure that if a valid graph is rendered
	# in case the buttons are disabled, they are enabled again
	if clear_button.disabled:
		clear_button.disabled = false
	if pin_checkbox.disabled:
		pin_checkbox.disabled = false
	if keep_emissions_checkbox.disabled:
		keep_emissions_checkbox.disabled = false
	if emission_speed_slider.editable:
		emission_speed_slider.editable = true
		emission_speed_icon.disabled = false

func create_node(node_name: String, title_appendix: String = "") -> SignalLensGraphNode:
	var new_node = SignalLensGraphNode.new()
	new_node.name = node_name
	new_node.title = node_name + " " + title_appendix
	return new_node

func create_button_slot(button_text: String, parent_node: GraphNode, slot_direction: Direction, slot_color: Color):
	var signal_button: Button = Button.new()
	signal_button.flat = true
	signal_button.name = button_text
	signal_button.text = button_text
	parent_node.add_child(signal_button)
	signal_button.pressed.connect(_on_signal_button_pressed.bind(parent_node, signal_button.get_index()))
	signal_button.focus_exited.connect(clean_connection_activity)
	parent_node.set_slot(signal_button.get_index(), slot_direction == Direction.LEFT, 0, slot_color, slot_direction == Direction.RIGHT, 0, slot_color)

func get_slot_color(slot_index, signal_amount) -> Color:
	var hue = float(slot_index) / float(signal_amount) 
	return Color.from_hsv(hue, 1.0, 0.5, connection_opacity)  

func clean_connection_activity():
	for connection in graph_edit.get_connection_list():
		graph_edit.set_connection_activity(connection["from_node"], connection["from_port"],  connection["to_node"], connection["to_port"], 0)

#endregion

#region Signal Emission Rendering

func draw_signal_emission(data: Array):
	logger.create_log(data[0]["datetime"], data[0]["timestamp"], data[0]["node_name"], data[0]["signal_name"], data[0]["signal_arguments"], data[0]["physics_frames"], data[0]["process_frames"])
	# Avoid trying to draw signal emission if graph not fully drawn yet
	if graph_edit.get_child_count() <= 1: return
	var target_node: GraphNode = graph_edit.get_child(1)
	var port_index = get_port_index_from_signal_name(data[0]["signal_name"])
	if port_index == -1: return
	for connection in graph_edit.get_connection_list():
		if connection["from_node"] == target_node.name && connection["from_port"] == port_index:
			pulse_connection(connection)


func pulse_connection(connection: Dictionary) -> void:
	if connection not in pulsing_connections: pulsing_connections.append(connection)
	
	var from_node = connection["from_node"]
	var from_port = connection["from_port"]
	var to_node = connection["to_node"]
	var to_port = connection["to_port"]
	
	if keep_emissions: 
		graph_edit.set_connection_activity(from_node, from_port, to_node, to_port, 1.0)
	else:
		fade_out_connection(connection)

func fade_out_connection(connection: Dictionary):
	var tween := create_tween()
	var fade_out_duration = DEFAULT_EMISSION_DURATION * emission_speed_multiplier
	var from_node = connection["from_node"]
	var from_port = connection["from_port"]
	var to_node = connection["to_node"]
	var to_port = connection["to_port"]
	
	tween.tween_method(
		func(value): graph_edit.set_connection_activity(from_node, from_port, to_node, to_port, value), 1.0, 0.0, fade_out_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(func(): pulsing_connections.erase(connection))

func get_port_index_from_signal_name(signal_name: String):
	var target_node = graph_edit.get_child(1)
	for child in target_node.get_children():
		if child.name == signal_name:
			return child.get_index()
	return -1

func keep_signal_emissions():
	keep_emissions = true

func dont_keep_signal_emissions():
	for connection in pulsing_connections:
		fade_out_connection(connection)
	keep_emissions = false

#endregion

#region Panel Resizing

# Reference to the Split Container that holds the bottom panel in the editor
var _editor_dock

# split_offset value of editor dock, works as a size for the panel
# Important: the value is negative because of split_offset's implementation
var _original_panel_size: float

## Grabs a reference to the parent split container of the debugger
func _get_parent_editor_split():
	var base = EditorInterface.get_base_control()
	var waiting := base.get_children()
	while not waiting.is_empty():
		var node := waiting.pop_back() as Node
		if node.name.find("DockVSplitCenter") >= 0:
			_editor_dock = node
			_original_panel_size = _editor_dock.split_offset
			if visible:
				_resize_panel(-ProjectSettings.get_setting("addons/Signal Lens/height_to_resize_to"))
			else:
				_resize_panel(0)
		else:
			waiting.append_array(node.get_children())

## Resizes panel to new_size if possible
func _resize_panel(new_size: float):
	if _can_resize_panel():
		_editor_dock.split_offset = new_size


func _can_resize_panel() -> bool:
	# If user wants to resize panel on open
	if not ProjectSettings.get_setting("addons/Signal Lens/resize_panel_on_open"): return false
	
	# If editor dock reference has been acquired
	if not _editor_dock: return false
	return true


func _on_visibility_changed() -> void:
	# Only resize bottom panel if both visible and visible in editor
	if visible and is_visible_in_tree():
		_resize_panel(-ProjectSettings.get_setting("addons/Signal Lens/height_to_resize_to"))
	else:  
		_resize_panel(_original_panel_size)

func _open_project_settings():
	var base = EditorInterface.get_base_control()

	# Find the Project Settings Editor
	var settings = base.find_child('*ProjectSettingsEditor*', true, false)
	if not settings:
		print('ProjectSettingsEditor not found (?)')
		return

	# Grab the tab container from the sectioned editor
	var tab_container = settings.find_child('*TabContainer*', true, false)
	if not tab_container is TabContainer:
		print('Could not find the tab container')
		return

	# Set the current tab to General
	tab_container.current_tab = 0

	# Find the Sectioned Editor inside it
	var sectioned_inspector = tab_container.find_child('*SectionedInspector*', true, false)
	if not sectioned_inspector:
		print('SectionedInspector not found (?)')
		return

	# Find the Tree inside it
	var tree = sectioned_inspector.find_child("Tree", true, false) as Tree
	if not tree:
		print('Could not find Tree')
		return

	# Find the entry in the tree
	var found_item = null
	var item = tree.get_root()
	while item:
		item = item.get_next_visible()
		if not item:
			print('--finished')
			break
		if item.get_text(0) == "Signal Lens":
			found_item = item
			break

	# Select the found item
	if found_item:
		tree.set_selected(found_item, 0)
		tree.ensure_cursor_is_visible()

	# Finally popup the Project Settings Editor
	settings.popup()

#endregion

#region Signal Callbacks

func _on_refresh_button_pressed() -> void:
	if current_node.is_empty(): return
	request_node_data()

func _on_signal_button_pressed(graph_node: GraphNode, internal_index: int):
	graph_edit.set_selected(null)
	clean_connection_activity()
	for connection in graph_edit.get_connection_list():
		if (connection["from_node"] == graph_node.name && connection["from_port"] == internal_index) or (connection["to_node"] == graph_node.name && connection["to_port"] == internal_index):
			graph_edit.set_connection_activity(connection["from_node"], connection["from_port"],  connection["to_node"], connection["to_port"], 0.75)

func _on_graph_edit_node_selected(node: Node) -> void:
	var graph_node = node as GraphNode
	for connection in graph_edit.get_connection_list():
		if connection["to_node"] == graph_node.name:
			graph_edit.set_connection_activity(connection["from_node"], connection["from_port"],  connection["to_node"], connection["to_port"], 0.75)

func _on_graph_edit_node_deselected(node: Node) -> void:
	var graph_node = node as GraphNode
	for connection in graph_edit.get_connection_list():
		if connection["to_node"] == graph_node.name:
			graph_edit.set_connection_activity(connection["from_node"], connection["from_port"],  connection["to_node"], connection["to_port"], 0)

func _on_clear_button_pressed() -> void:
	clear_graph()

func _on_repo_button_pressed() -> void:
	OS.shell_open("https://github.com/yannlemos/signal-lens")

func _on_pin_checkbox_toggled(toggled_on: bool) -> void:
	block_new_inspections = toggled_on

func _on_emission_speed_slider_value_changed(value: float) -> void:
	emission_speed_multiplier = value

func _on_keep_emissions_checkbox_toggled(toggled_on: bool) -> void:
	if toggled_on:
		keep_signal_emissions()
	else:
		dont_keep_signal_emissions()

func _on_logger_button_toggled(toggled_on: bool) -> void:
	logger.visible = toggled_on
	
func _on_options_index_pressed(option_index: int) -> void:
	if options_popup.is_item_checkable(option_index):
		settings[option_index] = not options_popup.is_item_checked(option_index) # Change state
		options_popup.set_item_checked(option_index, settings[option_index]) # Apply state
		
		if option_index in [Options.HIDE_SIGNALS_WITHOUT_CONNECTIONS, Options.HIDE_BUILT_IN_SIGNALS]:
			refresh_button.pressed.emit()
		elif option_index == Options.SHOW_GRAPH_TOOLBAR:
			graph_edit.get_menu_hbox().visible = settings[option_index]
		elif option_index == Options.SHOW_GRAPH_MINIMAP:
			graph_edit.minimap_enabled = settings[option_index]
	else:
		_open_project_settings()

func _on_connection_opacity_slider_value_changed(value: float) -> void:
	connection_opacity = value
	if graph_edit.get_child_count() <= 1: return
	var target_node: GraphNode = graph_edit.get_child(1)
	for slot_index in target_node.get_child_count():
		target_node.set_slot_color_right(slot_index, Color(target_node.get_slot_color_right(slot_index), connection_opacity))

#endregion
