@tool class_name Wheel extends Control
## Hello and welcome to the Persuasion Wheel Game Jam AKA WHEELJAM! This code
## is free to use and distribute for the purposes of WHEELJAM and any games
## you choose to make with it besides. Please provide attribution if you use it
## outside the jam. :)
## This code is also not required for WHEELJAM -- you are free to make your own
## implementation of the wheel, use your own assets, etc.
## Everything to make the wheel function is in this single script -- this is a 
## deliberate choice to keep it plug-n-play for the jam. I don't recommend 
## coding like this!
## Have fun and enjoy WHEELJAM!
## Love, Colin & Shane :)

#region Export Variables
@export_category("Wheel Cosmetics")
@export_group("Size & Scale")
## a vector2 that specifies the wheel's custom minimum size.
@export var wheel_size:Vector2 = Vector2(300,300):
	set(value):
		wheel_size = value
		if Engine.is_editor_hint(): self.custom_minimum_size = wheel_size
## specifies the wheel's scale.
@export_range(0,5,0.1) var wheel_scale:float = 1:
	set(value):
		wheel_scale = value
		self.scale.x = wheel_scale
		self.scale.y = wheel_scale
@export_group("Animations")
## controls the animation of the rotation of the wheel.
enum TweenType {
	TRANS_LINEAR,
	TRANS_SINE,
	TRANS_QUINT,
	TRANS_QUART,
	TRANS_QUAD,
	TRANS_EXPO,
	TRANS_ELASTIC,
	TRANS_CUBIC,
	TRANS_CIRC,
	TRANS_BOUNCE,
	TRANS_BACK,
	TRANS_SPRING
	}
@export var tween_type:TweenType = TweenType.TRANS_CIRC
## controls how long the rotation animation will play for.
@export_range(0,2,0.05) var anim_time= 0.3

@export_group("Textures")
## an array of slice textures. order is [slice1,slice2,slice3,slice4] (smallest to largest)
@export var slice_textures:Array[Texture2D] = []:
	set(value):
		slice_textures = value
		if Engine.is_editor_hint():
			_update_slices_ui(value)
## the underlay texture.
@export var underlay_texture:Texture2D = preload("res://the-wheel-godot/WHEEL/Assets/wheel-placeholder/underlay.png"):
	set(value):
		underlay_texture = value
		if Engine.is_editor_hint():
			_update_underlay_ui(underlay_texture)
## the overlay texture.
@export var overlay_texture:Texture2D = preload("res://the-wheel-godot/WHEEL/Assets/wheel-placeholder/overlay.png"):
	set(value):
		overlay_texture = value
		if Engine.is_editor_hint():
			_update_overlay_ui(overlay_texture)
## the selector texture.
@export var selector_texture:Texture2D = preload("res://the-wheel-godot/WHEEL/Assets/wheel-placeholder/selector.png"):
	set(value):
		selector_texture = value
		if Engine.is_editor_hint():
			_update_selector_ui(selector_texture)
#endregion

#region Onready Variables
## our triangles of varying sizes.
@onready var slices:Array[Control] = [%slice1,%slice2,%slice3,%slice4]
## our covers to indicate that the selection has already been chosen.
@onready var covers:Array[Control] = [%cover_up,%cover_down,%cover_left,%cover_right]
## a reference to our selector node.
@onready var selector:Control = %wheel_select
## a reference to our slice gimbal.
@onready var slice_gimbal:Control = %slice_gimbal
#endregion

#region Internal Variables
## enum dictating current state of wheel.
enum WheelState {AWAITING_SELECTION,ROTATING,NO_INPUT}
## variable containing current state of wheel.
var current_wheel_state:WheelState = WheelState.AWAITING_SELECTION
## where the selector currently is.
var current_direction:int = 0
## base score values for the slices
var base_numbers:Array[int] = [-2,-1,1,2]
## slice value multiplier
var slice_value_multiplier:Array[int] = [1,2,3,4]
## assigns values to directions; format is as follows: [UP,RIGHT,DOWN,LEFT]
var current_value_mappings:Array[int] = [0,90,180,270]
## how many selections have been chosen
var current_num_selections:int = 0
## how many selections are allowed; default is 4.
var target_selections:int = 4
## a WheelPayload object containing the wheel's value
var _current_value:WheelPayload
## rotation value (in degrees) for the wheel directions. [UP,RIGHT,DOWN,LEFT]
const DIRECTIONS:Array[int] = [0,90,180,270]
#endregion

#region Signals
## emitted when a new direction is selected.
signal new_dir_chosen
## emitted when the gimbal begins to be rotated.
signal rotation_started
## emitted when the gimbal is finished rotating.
signal rotation_finished
## emitted when the puzzle is complete.
signal puzzle_finished
#endregion

#region Built-In Functions
#called when the scene is loaded into the tree
func _ready()->void:
	reset()
	rotation_finished.connect(end_check)
	

# handles input for our minigame
func _unhandled_input(_event: InputEvent) -> void:
	# if up, down, left or right is pressed, process that direction input
	if Input.is_action_just_pressed("ui_up"):
		current_direction=0
		process_direction_input(current_direction)
	if Input.is_action_just_pressed("ui_down"):
		current_direction=180
		process_direction_input(current_direction)
	if Input.is_action_just_pressed("ui_left"):
		current_direction=270
		process_direction_input(current_direction)
	if Input.is_action_just_pressed("ui_right"):
		current_direction=90
		process_direction_input(current_direction)
	
	# if tab is pressed, rotate the slices
	if Input.is_action_just_pressed("ui_text_completion_replace"):
		rotate_slices()
		slice_value_multiplier =  _shift_array_right(slice_value_multiplier)
	
	# if space is pressed, confirm selection
	if Input.is_action_just_pressed("ui_accept"):
		process_confirm_input(current_direction,true)
#endregion

#region Custom Functions
## processes the input direction and moves the selector to that direction.
func process_direction_input(direction:int,debug=false)->void:
	#print debug info if enabled
	if debug: print("moving selector to "+str(direction)+" degrees"+"\n")
	#move our selector to the direction
	selector.rotation_degrees = direction
	#set the current wheel value to our slice and base values
	_current_value = get_current_wheel_value()
	print(_current_value.base_value)
	print(_current_value.slice_value)
	print(_current_value.total_value)
	#emit new direction chosen signal
	new_dir_chosen.emit()

## confirms that the current selection has been chosen
func process_confirm_input(direction:int,debug=false)->void:
	# if the wheel isn't ready, stop the confirmation process
	if current_wheel_state != WheelState.AWAITING_SELECTION:
		return
	# iterate through our cover; if the rotation of the cover is equal to our
	# selection's rotation, then we know we have the right cover. 
	for x in %covers.get_children(): 
		# rounded because I was getting weird floating point results. 
		if int(round(x.rotation_degrees)) == direction:
			# prints debug if enabled in signature
			if debug: print("selecting "+str(direction)+" degrees\n")
			# if the cover is already visible, then it's been selected before.
			if x.visible: return 
			# set cover to visible
			x.visible = true 
			# set the number of selections +=1
			current_num_selections += 1 
			# rotate the gimbal
			rotate_slices()
			# exit out if the cover has been found
			return 

## rotates the slice gimbal +90 degrees
func rotate_slices(debug=false)->void:
	# if we aren't awaiting a selection, don't rotate
	if current_wheel_state != WheelState.AWAITING_SELECTION:
		return
	# prints debug info if enabled
	if debug: print("rotating gimbal +90 degrees\n")
	# set the current wheel state to show it is rotating
	current_wheel_state = WheelState.ROTATING
	# emit rotation started signal
	rotation_started.emit()
	# create our tween object we will use for the animation
	var tween:Tween = create_tween()
	# sets our transition type to our enum
	tween.set_trans(int(tween_type))
	# rotates gimbal for our specified time in anim time
	tween.tween_property(%slice_gimbal, "rotation_degrees",%slice_gimbal.rotation_degrees+90,anim_time)
	# runs the end_check function when the tween is done
	tween.finished.connect(end_check)

## this function resets the minigame.
func reset()->void:
	# ensures that godot will randomize the shuffle of the mappings
	randomize()
	# remove this if you don't want the selector to reset up every time
	%wheel_select.rotation_degrees = 0
	# resets gimbal
	%slice_gimbal.rotation_degrees = 0
	# resets number of selections that have been chosen
	current_num_selections = 0
	# hides the covers
	for x in covers: x.visible = false
	# chooses a random order for our value mappings
	current_value_mappings.shuffle()
	# sets the slice rotations to our value mappings
	for x in current_value_mappings.size():
		slices[x].rotation_degrees = current_value_mappings[x]
	# assigns the slice value to the direction of the corresponding slice
	for x in DIRECTIONS.size():
		for j in current_value_mappings.size():
			if DIRECTIONS[x] == current_value_mappings[j]:
				slice_value_multiplier[x] = x+1
	# shuffles base numbers so random wheel segments = a random base number
	base_numbers.shuffle()
	# sets our current wheel value
	_current_value = get_current_wheel_value()
	# sets the current wheel state to awaiting a selection
	current_wheel_state = WheelState.AWAITING_SELECTION

## checks if the minigame is finished
func end_check()->void:
	# if the current number of selections is the total number of selections allowed
	if current_num_selections == target_selections:
		# the wheel state is no longer taking input
		current_wheel_state = WheelState.NO_INPUT
		# puzzle finished signal is emitted
		puzzle_finished.emit()
	else:
		# otherwise, the wheel is awaiting a selection
		current_wheel_state = WheelState.AWAITING_SELECTION

## returns the wheel value
func get_current_wheel_value()->WheelPayload:
	# create a new wheelpayload object
	var wp = WheelPayload.new()
	# for every value in our value mappings...
	for x in current_value_mappings.size():
		# if the selector's current direction is equal to our value mapping
		if current_direction == current_value_mappings[x]:
			# set our values
			wp.base_value = base_numbers[x]
			wp.slice_value = slice_value_multiplier[x]
			wp.total_value = wp.base_value * wp.slice_value
	return wp
#endregion

#region helper functions
# this function will help us account for rotating the gimbal.
func _shift_array_right(arr: Array) -> Array:
	var a = arr
	if a.size() <= 1:
		return [] 
	var last_element = arr[-1]
	a.pop_back()  # Remove the last element
	a.push_front(last_element)  # Add it to the front
	return a

# this is all UI stuff. I got weird errors if I didn't split up the selector and overlay etc pls don't judge me.
func _update_slices_ui(new_textures:Array[Texture2D])->void:
	for x in slices.size():
		slices[x].texture = new_textures[x]
		slices[x].pivot_offset = Vector2(new_textures[x].get_size().x/2,new_textures[x].get_size().y/2)
		slices[x].position = Vector2.ZERO
		slices[x].set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		slices[x].size = new_textures[x].get_size()
	for x in covers.size():
		covers[x].texture = new_textures[3]
		covers[x].modulate = Color("000000a8")
		covers[x].pivot_offset = Vector2(Vector2(new_textures[3].get_size().x/2,new_textures[3].get_size().y/2))
		covers[x].position = Vector2.ZERO
		covers[x].set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		covers[x].size = new_textures[3].get_size()

func _update_selector_ui(new_texture:Texture2D)->void:
	var node:=%wheel_select
	node.texture = new_texture
	node.pivot_offset = Vector2(new_texture.get_size().x/2,new_texture.get_size().y/2)
	node.position = Vector2.ZERO
	node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	node.size = new_texture.get_size()
func _update_overlay_ui(new_texture:Texture2D)->void:
	var node:=%overlay
	node.texture = new_texture
	node.pivot_offset = Vector2(new_texture.get_size().x/2,new_texture.get_size().y/2)
	node.position = Vector2.ZERO
	node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	node.size = new_texture.get_size()
func _update_underlay_ui(new_texture:Texture2D)->void:
	var node:=%underlay
	node.texture = new_texture
	node.pivot_offset = Vector2(new_texture.get_size().x/2,new_texture.get_size().y/2)
	node.position = Vector2.ZERO
	node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	node.size = new_texture.get_size()

#endregion

#region WheelPayload Class
## allows us to create wheel payload object and assign values to wheel.
class WheelPayload:
	var base_value:int
	var slice_value:int
	var total_value:int
#endregion
