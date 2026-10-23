extends SceneTree
## Headless checks: godot --headless --path . --script tests/test_hold_to_confirm.gd

var failures: int = 0


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _key(button: Button, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	button.get_viewport().push_input(event)


func _mouse(button: Button, pressed: bool) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	button.get_viewport().push_input(motion)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	button.get_viewport().push_input(event)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _initialize() -> void:
	var button: HoldToConfirmButton = HoldToConfirmButton.new()
	button.verb = "Forge"
	# The headless window is 64x64 pixels and can't be resized, so the button sits inside it.
	button.position = Vector2(2, 2)
	button.size = Vector2(60, 40)
	button.clip_text = true
	root.add_child(button)
	var fired: Array[int] = [0]
	var cancels: Array[int] = [0]
	button.confirmed.connect(func() -> void: fired[0] += 1)
	button.cancelled.connect(func() -> void: cancels[0] += 1)
	await process_frame

	check(button.text == "Hold to forge", "idle label: Hold to forge")
	_mouse(button, true)
	await _wait(0.2)
	check(button.text == "Keep holding…" and button.progress > 0.0, "holding fills the line and says Keep holding…")
	_mouse(button, false)
	await _wait(0.05)
	check(fired[0] == 0 and cancels[0] == 1, "letting go early cancels without confirming")
	await _wait(0.3)
	check(button.progress == 0.0, "the line drains back to empty")

	_mouse(button, true)
	await _wait(0.8)
	_mouse(button, false)
	check(fired[0] == 1, "a 0.6 s mouse hold confirms once")

	button.grab_focus()
	_key(button, true)
	await _wait(0.8)
	_key(button, false)
	await process_frame
	check(fired[0] == 2, "holding Enter on the focused button confirms once (fired %d)" % fired[0])

	button.mode = HoldToConfirmButton.Mode.PRESS_TWICE
	check(button.text == "Forge", "press-twice idle label is the verb")
	_key(button, true)
	await process_frame
	_key(button, false)
	await process_frame
	check(button.text == "Press again to forge" and fired[0] == 2, "one key press arms without confirming")
	_key(button, true)
	await process_frame
	_key(button, false)
	await process_frame
	check(fired[0] == 3, "a second press inside the window confirms")

	button.arm_seconds = 0.5
	_mouse(button, true)
	await process_frame
	_mouse(button, false)
	await _wait(0.7)
	check(not button.is_armed() and button.text == "Forge" and fired[0] == 3, "the arm runs out after arm_seconds")

	button.disabled = true
	_mouse(button, true)
	await process_frame
	_mouse(button, false)
	check(not button.is_armed(), "a disabled button ignores presses")
	button.queue_free()
	await process_frame
	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
