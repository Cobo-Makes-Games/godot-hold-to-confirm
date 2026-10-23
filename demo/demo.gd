extends Control
## Hold To Confirm demo: hold the button (or Enter / A while it's focused) to
## forge; switch to Press twice for players who can't hold a button.

@onready var forge: HoldToConfirmButton = $Box/Forge
@onready var status: Label = $Box/Status
var forged: int = 0


func _ready() -> void:
	forge.confirmed.connect(func() -> void:
		forged += 1
		status.text = "Forged %d time%s." % [forged, "" if forged == 1 else "s"])
	forge.cancelled.connect(func() -> void: status.text = "Cancelled: nothing was spent.")
	$Box/Mode.item_selected.connect(func(index: int) -> void: forge.mode = index as HoldToConfirmButton.Mode)
	$Box/Reduced.toggled.connect(func(on: bool) -> void: forge.reduced_motion = on)
	forge.grab_focus()
