extends Control
## A simple script that shows how to implement the wheel in a minigame.
## It features my cat Olive. She's a baby.


#region Onready Variables
@onready var wheel:Control = %WHEEL
#endregion

#region Internal Variables
var select_sound:AudioStream = preload("res://the-wheel-godot/WHEEL/Demo/assets/selector_click.wav")
var rotate_sound:AudioStream = preload("res://the-wheel-godot/WHEEL/Demo/assets/rotate.wav")
var success_sound:AudioStream = preload("res://the-wheel-godot/WHEEL/Demo/assets/success.wav")
var fail_sound:AudioStream = preload("res://the-wheel-godot/WHEEL/Demo/assets/fail.mp3")
var current_wheel_value:int = 0


var game_over = false

#endregion

#region Built-In Functions
func _ready():
	# connects the new dir chosen signal to a lambda function that plays the selector sound 
	wheel.new_dir_selected.connect(func():if wheel.num_selections != wheel.target_selections: _play_sound(select_sound))
	# connects our new dir chosen signal to the update wheel value function
	wheel.new_dir_chosen.connect(update_wheel_value)
	# connects the dir confirmed signal to a lambda function that plays the confirm sound
	wheel.rotation_started.connect(func():_play_sound(rotate_sound))

func _process(_delta: float) -> void:
	if game_over: return
	
	update_text()
	show_value(wheel._current_value.base_value)
	
	if wheel.num_selections == wheel.target_selections:
		end_check(current_wheel_value)
	
#endregion

#region Custom Functions
# the new_dir_chosen signal passes the current wheel value of the chosen segment
func update_wheel_value(_current_value):
	current_wheel_value += _current_value.total_value

func end_check(wheel_val):
	if wheel_val > 0:
		$game_overs/pass.visible = true
		_play_sound(success_sound)
	else:
		$game_overs/fail.visible = true
		_play_sound(fail_sound)
	game_over = true

# updates our debug labels
func update_text()->void:
	var slice = "Slice Value: "+str(wheel._current_value.slice_value)
	var base = "Base Value: "+str(wheel._current_value.base_value)
	var selections = "Number of Selections: "+str(wheel.num_selections)
	var bases = "Base Values: "+str(wheel.base_numbers)
	var value_mappings = "Value Mappings: "+str(wheel.current_value_mappings)
	var slice_multipliers = "Slice Multipliers: "+str(wheel.slice_values)
	$"text/wheel value".text = "Wheel value: "+str(current_wheel_value)
	$"text/slice value".text = slice
	$"text/base value".text = base
	$"text/num selections".text = selections
	$"text/value mappings".text = value_mappings
	$"text/base values".text = bases
	$"text/slice multipliers".text = slice_multipliers
	
# toggles our visible olive picture and background color to indicate base values
func show_value(base_value)->void:
	var b = wheel._current_value.base_value
	var olives = $values.get_children()
	var colors = $colors.get_children()
	# this assumes that the colors and the values have children in the same order
	# with the same names.
	for x in olives.size():
		if olives[x].name == str(b):
			olives[x].visible = true
			colors[x].visible = true
		else:
			olives[x].visible = false
			colors[x].visible = false
			
#endregion

#region Helper Functions
# helper function that plays our sounds modulated at a random pitch range of 0.95-1.05
func _play_sound(sound:AudioStream)->void:
	randomize()
	var player = AudioStreamPlayer.new()
	player.stream = sound
	player.pitch_scale = randf_range(0.95,1.05)
	self.add_child(player)
	player.play()
	player.finished.connect(func():player.queue_free())
#endregion
