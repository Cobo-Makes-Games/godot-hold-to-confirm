@icon("res://addons/hold_to_confirm/icon.svg")
class_name HoldToConfirmButton
extends Button
## A button for actions players shouldn't trigger by accident (spending a lot,
## deleting a save): hold it until a line along its bottom edge fills, or, for
## players who can't hold a button, press it twice within a few seconds.
## Letting go early cancels and the line drains away.
##
##   $Forge.confirmed.connect(_forge)
##
## From Mytheria (cobomakesgames.com/blog/accessibility-settings-in-games/).

## Emitted once when the action is confirmed.
signal confirmed
## Emitted when a hold is released early or a press-twice arm runs out.
signal cancelled

enum Mode { HOLD, PRESS_TWICE }

## The action, shown as "Hold to forge", "Keep holding…", "Press again to forge".
@export var verb: String = "Confirm":
	set(value):
		verb = value
		_update_label()
## Hold, or press twice. Offer both as a player setting.
@export var mode: Mode = Mode.HOLD:
	set(value):
		mode = value
		cancel()
@export_range(0.1, 5.0, 0.05) var hold_seconds: float = 0.6
## How fast an early release drains the line.
@export_range(0.0, 2.0, 0.01) var drain_seconds: float = 0.15
## How long the first press stays armed in press-twice mode.
@export_range(0.5, 10.0, 0.1) var arm_seconds: float = 3.0
@export var fill_color: Color = Color("f0d98f")
@export_range(1.0, 8.0, 0.5) var fill_height: float = 3.0
## Reduced motion: no drain animation and no press nudge. The fill still shows progress.
@export var reduced_motion: bool = false

var progress: float = 0.0
var holding: bool = false
var _armed_until_ms: int = 0
var _pressed_by_key: bool = false


func _ready() -> void:
	button_down.connect(begin)
	button_up.connect(release)
	_update_label()


## Starts a hold, or in press-twice mode arms the button or confirms it.
func begin() -> void:
	if disabled:
		return
	if mode == Mode.PRESS_TWICE:
		if is_armed():
			_fire()
		else:
			_armed_until_ms = Time.get_ticks_msec() + int(arm_seconds * 1000.0)
			_update_label()
		return
	holding = true
	_update_label()


## Ends a hold. Before the line is full, nothing happens and it drains.
func release() -> void:
	if not holding:
		return
	holding = false
	if progress > 0.0 and progress < 1.0:
		cancelled.emit()
	_update_label()


## Resets the button without confirming.
func cancel() -> void:
	var was_busy: bool = holding or is_armed()
	holding = false
	_armed_until_ms = 0
	progress = 0.0
	queue_redraw()
	_update_label()
	if was_busy:
		cancelled.emit()


func is_armed() -> bool:
	return _armed_until_ms > 0 and Time.get_ticks_msec() < _armed_until_ms


func _process(delta: float) -> void:
	if _armed_until_ms > 0 and not is_armed():
		_armed_until_ms = 0
		_update_label()
		cancelled.emit()
	if holding:
		progress = minf(1.0, progress + delta / hold_seconds)
		queue_redraw()
		if progress >= 1.0:
			_fire()
	elif progress > 0.0:
		progress = 0.0 if reduced_motion or drain_seconds <= 0.0 else maxf(0.0, progress - delta / drain_seconds)
		queue_redraw()


## Keyboard and controller: ui_accept held down drives the same hold as the mouse.
func _gui_input(event: InputEvent) -> void:
	if event.is_action("ui_accept") and not event.is_echo():
		if event.is_pressed() and not _pressed_by_key:
			_pressed_by_key = true
			begin()
			accept_event()
		elif event.is_released() and _pressed_by_key:
			_pressed_by_key = false
			release()
			accept_event()


func _fire() -> void:
	progress = 0.0
	holding = false
	_armed_until_ms = 0
	queue_redraw()
	_update_label()
	if not reduced_motion:
		# A one-pixel settle, so the button feels pressed home.
		position.y += 1.0
		get_tree().create_timer(0.08).timeout.connect(func() -> void: position.y -= 1.0)
	confirmed.emit()


func _update_label() -> void:
	if holding:
		text = "Keep holding…"
	elif is_armed():
		text = "Press again to %s" % verb.to_lower()
	elif mode == Mode.HOLD:
		text = "Hold to %s" % verb.to_lower()
	else:
		text = verb


func _draw() -> void:
	if progress <= 0.0:
		return
	var inset: float = 6.0
	var track: Rect2 = Rect2(Vector2(inset, size.y - fill_height - 4.0), Vector2(size.x - inset * 2.0, fill_height))
	draw_rect(track, Color(0, 0, 0, 0.45))
	draw_rect(Rect2(track.position, Vector2(track.size.x * progress, fill_height)), fill_color)
