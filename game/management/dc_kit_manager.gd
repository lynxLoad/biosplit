extends Node

func _ready() -> void:
	#DCKit.toggle_console()
	#DCKit.show_console()
	
	DCKit.console_visibility_changed.connect(_on_console_visibility_changed)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.is_action_pressed("toggle_console"):
		DCKit.toggle_console()
		get_viewport().set_input_as_handled()
		return

func _on_console_visibility_changed(is_open: bool) -> void:
	if is_open:
		PauseManager.pause(PauseManager.PauseType.MENU)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		PauseManager.unpause(PauseManager.PauseType.MENU)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
