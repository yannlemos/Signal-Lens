## Initializes Signal Lens plugin and its internal components
@tool
extends EditorPlugin

## Preloaded reference to the editor panel that will be added to 
## Godot's debugger bottom panel
const SIGNAL_LENS_EDITOR_PANEL = preload("res://addons/signal_lens/editor/signal_lens_editor_panel.tscn")

## Name of autoload node/class that will be instantiated in the remote scene
## so we can retrieve/send data to it
const AUTOLOAD_NAME = "SignalLens"

## Debugger object that listens to Godot's callbacks
var debugger: SignalLensDebugger = null

## Inspector plugin that allows selecting remote scene nodes
var remote_node_inspector: SignalLensRemoteNodeInspector = null

## Editor panel that draws data received from remote scene
var editor_panel: SignalLensEditorPanel = null


## Setups the plugin and connects internal components
## Called on enter editor scene tree
func initialize():
	# Create debugger and inspector objects
	debugger = SignalLensDebugger.new()
	remote_node_inspector = SignalLensRemoteNodeInspector.new()
	
	# Register plugins in the engine
	add_inspector_plugin(remote_node_inspector)
	add_debugger_plugin(debugger)
	
	# Add plugin project settings
	setup_project_settings()
	
	# Connect node selection in scene tree to backend request for
	# that node's signal data
	remote_node_inspector.node_selected.connect(debugger.request_node_data_from_remote)
	
	# Create editor panel and add it to the debugger
	editor_panel = SIGNAL_LENS_EDITOR_PANEL.instantiate()
	debugger.setup_editor_panel(editor_panel)
	
	# Connect data received from debugger to editor panel so data can be
	# rendered in graph form
	debugger.received_node_data_from_remote.connect(editor_panel.draw_node_data)
	
	# Connect signal emissions from targeted node to editor panel
	# so they can be rendered in the graph
	debugger.received_signal_emission_from_remote.connect(editor_panel.draw_signal_emission)
	
	# Connect refresh request to debugger so we can retrieve data from
	# currently selected node on demand
	editor_panel.node_data_requested.connect(debugger.request_node_data_from_remote)
	
	# Connect start and stop debugging signals for editor panel setup/cleanup
	debugger.started.connect(editor_panel.start_session)
	debugger.stopped.connect(editor_panel.stop_session)
	
	# Connect node selection to editor panel so line edit can reflect currently
	# selected node's path
	remote_node_inspector.node_selected.connect(editor_panel.assign_node_path)


## Creates and sets default values for Project Settings related to the plugin
func setup_project_settings():
	# Resize on open
	var setting_resize_panel_on_open = "addons/Signal Lens/resize_panel_on_open"
	if not ProjectSettings.has_setting(setting_resize_panel_on_open):
		ProjectSettings.set_setting(setting_resize_panel_on_open, true)
	ProjectSettings.add_property_info({
		"name": setting_resize_panel_on_open,
		"type": TYPE_BOOL,
		"hint": TYPE_BOOL,
		"hint_string": TYPE_BOOL
		})
	ProjectSettings.set_initial_value(setting_resize_panel_on_open, true)
	ProjectSettings.set_as_basic(setting_resize_panel_on_open, true)

	# Resize on open
	var setting_height_to_resize_to = "addons/Signal Lens/height_to_resize_to"
	if not ProjectSettings.has_setting(setting_height_to_resize_to):
		ProjectSettings.set_setting(setting_height_to_resize_to, 500)
	ProjectSettings.add_property_info({
		"name": setting_height_to_resize_to,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "200, 900"
		})
	ProjectSettings.set_initial_value(setting_height_to_resize_to, 500)
	ProjectSettings.set_as_basic(setting_height_to_resize_to, true)


## Removes plugin from editor and cleans references
func cleanup():
	# De-register plugins from engine
	remove_debugger_plugin(debugger)
	remove_inspector_plugin(remote_node_inspector)
	
	# Remove references to initialized components
	remote_node_inspector = null
	debugger = null
	editor_panel = null


#region Engine Callbacks

func _enter_tree() -> void:
	initialize()

func _exit_tree() -> void:
	cleanup()

func _enable_plugin():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/signal_lens/autoload/signal_lens_autoload.gd")

func _disable_plugin():
	remove_autoload_singleton(AUTOLOAD_NAME)

#endregion
