## Initializes a hidden inspector plugin that 
## enables the automatic grabbing of node paths when selecting them
## in the remote scene
class_name SignalLensRemoteNodeInspector 
extends EditorInspectorPlugin

## Emitted on user selection of node in remote scene
signal node_selected(node_path: NodePath)

func _can_handle(object: Object) -> bool:
	if object.get_property_list()[0]["name"] == "SectionedInspectorFilter": return false
	return object.get('Node/path') != null


func _parse_begin(object: Object) -> void:
	node_selected.emit(object.get('Node/path'))
