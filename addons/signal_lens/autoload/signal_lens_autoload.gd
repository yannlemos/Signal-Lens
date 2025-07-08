## This autoload is responsible for receiving the node path that will be inspected
## from the editor panel and then sending back all the signal data from that node
## parsed into a debugger friendly array
extends Node

## Reference to the currently targeted node in the remote tree
var target_node: Node = null

## On singleton ready in scene
## subscribe to the editor panel's request
func _ready() -> void:
	EngineDebugger.register_message_capture("signal_lens", _on_node_signal_data_requested)

## This callback parses a node's signal data into an array that can be sent to the debugger
## The data is packaged in the following structure:
## Pseudo-code: [Name of target node, [All of the node's signals and each signal's respective callables], Class of target node]
## This request is received in the debugger with an array containing the target node's node path
## which will be used to retrieve the target node from the scene
func _on_node_signal_data_requested(prefix, data) -> bool:
	var new_target_node = get_tree().root.get_node(data[0])

	# If node is not found, return false
	# If found, keep going
	if new_target_node == null:
		printerr("No node found in path " + str(data[0]))
		return false
	
	# Avoid error when trying to inspect root node
	if new_target_node == get_tree().root:
		EngineDebugger.send_message("signal_lens:incoming_node_signal_data", ["Root"])
		return false
	
	# Disconnect this autoload's callable connections from the previously targeted node's signals
	if target_node != null:
		if target_node != new_target_node:
			for signal_name in target_node.get_signal_list().map(func(p_signal): return p_signal["name"]):
				if target_node.is_connected(signal_name, _on_target_node_signal_emitted):
					target_node.disconnect(signal_name, _on_target_node_signal_emitted)
	
	# Acquire newly targeted node reference
	target_node = new_target_node
	
	# Initialize the first piece of data that will be sent to the debugger
	# The unique name of the targeted node
	# This will be used to set the name of the main graph node in the editor panel
	var target_node_name: String = target_node.name
	
	# Get target node class using Object.get_class()
	var target_node_class: String = target_node.get_class()
	
	# Initialize the array that will store the node's signal data
	var target_node_signal_data: Array
	
	# Get unparsed signal data from target node
	var target_node_signal_list: Array[Dictionary] = target_node.get_signal_list()
	
	# Iterate all signals in target node and parse signal data 
	# to debugger-friendly format
	for i in range(target_node_signal_list.size()):
		
		var raw_signal_data: Dictionary = target_node_signal_list[i]
		# Raw signal data is formatted as:
		# [name] is the name of the method, as a String
		# [args] is an Array of dictionaries representing the arguments
		# [default_args] is the default arguments as an Array of variants
		# [flags] is a combination of MethodFlags
		# [id] is the method's internal identifier int
		# [return] is the returned value, as a Dictionary;
		
		# Parse signal name
		var parsed_signal_name: String = raw_signal_data["name"]
		
		# Parse signal callables
		var raw_signal_connections: Array[Dictionary] = target_node.get_signal_connection_list(raw_signal_data["name"])
		# Raw signal connection is formatted as:
		# [signal] is a reference to the Signal;
		# [callable] is a reference to the connected Callable;
		# [flags] is a combination of ConnectFlags.
		
		var parsed_signal_callables = parse_signal_callables_to_debugger_format(raw_signal_connections)
		
		# Create debugger-friendly signal data dictionary
		var parsed_signal_data: Dictionary = {
				"signal": parsed_signal_name,
				"callables": parsed_signal_callables
			}
			
		# Append to overall signal data that will be sent to debugger
		target_node_signal_data.append(parsed_signal_data)
		
		# Connect this autoload's signal emission capture callable to currently iterated signal
		# so we can send signal emissions to the editor panel
		if not target_node.is_connected(parsed_signal_name, _on_target_node_signal_emitted):
			var signal_args: Array = raw_signal_data["args"]
			if signal_args.size() > 0:
				target_node.connect(parsed_signal_name, _on_target_node_signal_emitted.bind(target_node_name, parsed_signal_name).unbind(signal_args.size()))
			else:
				target_node.connect(parsed_signal_name, _on_target_node_signal_emitted.bind(target_node_name, parsed_signal_name))
				
	# On node data ready, prepare the array as per the debugger's specifications
	EngineDebugger.send_message("signal_lens:incoming_node_signal_data", [target_node_name, target_node_signal_data, target_node_class])
	return true


func parse_signal_callables_to_debugger_format(raw_signal_connections):
	var parsed_signal_callables: Array[Dictionary]
	# Iterate all connections of signal to parse callables
	for raw_signal_connection: Dictionary in raw_signal_connections:
		var parsed_callable_object: Object = raw_signal_connection["callable"].get_object()
		var parsed_callable_object_name: String
		
		# If object has property "name", get this property
		# Otherwise, get the string value of the object
		# This is important to allow parsing anonymous lambdas, which
		# don't have name properties. The names in the nodes are not
		# very user-friendly right now, so this is a good spot for a 
		# TODO: improve readability of anonymous lambda nodes
		if not parsed_callable_object: return {"object_name": "ERROR: Couldn't parse node name."}
		if parsed_callable_object.get("name") != null:
			parsed_callable_object_name = parsed_callable_object.get("name")
		else:
			parsed_callable_object_name = parsed_callable_object.to_string()
		
		var parsed_callable_method_name = str(raw_signal_connection["callable"].get_method())
		
		# Don't parse callable that is in this autoload
		if parsed_callable_method_name == "_on_target_node_signal_emitted": continue
		
		var parsed_callable_data = {
			"object_name": parsed_callable_object_name, 
			"method_name": parsed_callable_method_name
			}
		
		parsed_signal_callables.append(parsed_callable_data)
	return parsed_signal_callables


## This callable receives all signal emissions from the currently targeted node
## and sends them to the editor panel

func _on_target_node_signal_emitted(node_name: String, signal_name: String):
	var emission_data: Dictionary = {
		"node_name": node_name,
		"signal_name": signal_name,
		"signal_arguments": [], # NOTE: Empty for now, will be available in a future release targeting Godot 4.5
		"datetime": get_current_datetime_string(),
		"timestamp": get_engine_ticks_string(),
		"process_frames": Engine.get_process_frames(),
		"physics_frames": Engine.get_physics_frames(),
	}
	
	EngineDebugger.send_message("signal_lens:incoming_node_signal_emission", [emission_data])


# NOTE: This function is compatible with Godot 4.5+ only, but 1.4.0 version of Signal Lens 
# will still support 4.3+, so I'm keeping it here so it can reimplemented in a future release.
#func _on_target_node_signal_emitted(...args: Array):
	#
	#var parsed_args: Array
	#var signal_args = args.slice(0, args.size() - 2)
	#for arg in signal_args:
		#parsed_args.append(str(arg))
	#
	#var emission_data: Dictionary = {
		#"node_name": args[args.size() - 2],
		#"signal_name": args[args.size() - 1],
		#"datetime": get_current_datetime_string(),
		#"timestamp": get_engine_ticks_string(),
		#"process_frames": Engine.get_process_frames(),
		#"physics_frames": Engine.get_physics_frames(),
		#"signal_arguments": parsed_args
	#}
	#
	#EngineDebugger.send_message("signal_lens:incoming_node_signal_emission", [emission_data])

func get_current_datetime_string() -> String:
	return Time.get_datetime_string_from_system()

func get_engine_ticks_string() -> String:
	var ticks: int = Time.get_ticks_msec()
	
	# Convert milliseconds to total seconds
	var total_seconds = ticks / 1000
	var milliseconds = ticks % 1000
	
	# Calculate hours, minutes, and seconds
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	var seconds = total_seconds % 60
	
	# Format with leading zeros
	return "%02d:%02d:%02d:%03d" % [hours, minutes, seconds, milliseconds]
