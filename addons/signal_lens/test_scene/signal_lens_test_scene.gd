extends Control

signal counter_updated(new_value: int)

@onready var counter_value_label: Label = $VBoxContainer/Counter/CounterValueLabel

var _counter: int = 0

func _ready() -> void:
	counter_updated.connect(func(value): print("Signal fired from anonymous lambda! Value is " + str(value)))
	$VBoxContainer/AddButton.pressed.connect(_on_add_button_pressed.bind(1))

func _on_counter_updated(new_value: int) -> void:
	counter_value_label.text = str(new_value)

func _on_add_button_pressed(value: int) -> void:
	_counter += value
	counter_updated.emit(_counter)

func _on_counter_value_label_focus_entered() -> void:
	print("Player checking out counter value")
