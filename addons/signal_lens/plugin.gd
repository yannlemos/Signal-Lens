## Responsible for Signal Lens' initialization as an editor plugin for and
## registering the editor callbacks for both editor debugger and the runtime autoload
## that are critical for the plugin to run
@tool
extends EditorPlugin

const AUTOLOAD_NAME = "SignalLens"
var signal_lens_debugger = SignalLensDebugger.new()

#region Plugin Callbacks

func _on_node_selected(node_path: NodePath) -> void:
	signal_lens_debugger.editor.signal_bus_data_requested.emit(node_path)

func _enter_tree() -> void:
	add_debugger_plugin(signal_lens_debugger)
	remote_node_inspector = RemoteNodeInspector.new()
	remote_node_inspector.node_selected.connect(_on_node_selected)
	add_inspector_plugin(remote_node_inspector)

func _exit_tree() -> void:
	remove_debugger_plugin(signal_lens_debugger)
	remove_inspector_plugin(remote_node_inspector)
	remote_node_inspector = null

func _enable_plugin():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/signal_lens/signal_lens_runtime.gd")

func _disable_plugin():
	remove_autoload_singleton(AUTOLOAD_NAME)

#endregion

var remote_node_inspector: RemoteNodeInspector
		

class RemoteNodeInspector extends EditorInspectorPlugin:
	signal node_selected(node_path: NodePath)
	
	func _can_handle(object: Object) -> bool:
		return object.get('Node/path') != null
		
	func _parse_begin(object: Object) -> void:
		node_selected.emit(object.get('Node/path'))

## Backend debugger class that is necessary for debugger plugins
## Handles debugger callbacks such as receiving and sending data 
## to the project that is playing and setting up the debugging panel
## inside the editor
class SignalLensDebugger extends EditorDebuggerPlugin:
	## Preloaded reference to the debugger panel
	const SIGNAL_LENS_EDITOR = preload("res://addons/signal_lens/signal_lens_editor.tscn")
	
	## This prefix is used to separate messages from this debugger
	## as being specific to the plugin
	const debugger_message_prefix := "signal_lens"
	
	## Runtime reference to the debugger panel
	var editor: SignalLensEditor
		
	## This override is necessary so you can send and receive
	## messages from the project that is playing
	func _has_capture(prefix):
		return debugger_message_prefix
	
	## Called when project starts playing
	func _setup_session(session_id):
		# Instantiating the editor panel
		editor = SIGNAL_LENS_EDITOR.instantiate()
		# Connecting "inspect" button signal to debugger
		var session = get_session(session_id)
		editor.signal_bus_data_requested.connect(_on_signal_bus_data_requested.bind(session_id))
		# Adding editor to the debugger panel
		session.add_session_tab(editor)
		# Connecting the debugging sessions started/end to the cleanup of
		# the editor's graph
		session.started.connect(editor.clear_graph)
		session.stopped.connect(editor.clear_graph)
	
	## On data from autoload received, send it to the debugger panel
	func _capture(message, data, session_id):
		if message == "signal_lens:incoming_node_signal_data":
			editor.receive_signal_bus_data(data)
	
	## Called when you press the "inspect" button in the editor
	## Sends message with request to the autoload to find the [node_path]
	## It will then send it back as a message to the debugger if found
	## The message must be sent as an array, so the autoload must retrieve the [0] index
	## on receiving the message to get the node path
	func _on_signal_bus_data_requested(node_path, session_id: int):
		get_session(session_id).send_message("signal_lens:node_signal_data_requested", [node_path])
