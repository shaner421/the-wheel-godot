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

#region Signals
## emitted when a new direction is selected.
signal new_dir_selected()
## emitted when a direction is chosen
signal new_dir_chosen(payload:WheelPayload)
## emitted when the gimbal begins to be rotated.
signal rotation_started
## emitted when the gimbal is finished rotating.
signal rotation_finished
## emitted when the puzzle is complete.
signal puzzle_finished
#endregion

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
			_update_node_ui(get_node_or_null("%underlay"),underlay_texture)
## the overlay texture.
@export var overlay_texture:Texture2D = preload("res://the-wheel-godot/WHEEL/Assets/wheel-placeholder/overlay.png"):
	set(value):
		overlay_texture = value
		if Engine.is_editor_hint():
			_update_node_ui(get_node_or_null("%overlay"),underlay_texture)
## the selector texture.
@export var selector_texture:Texture2D = preload("res://the-wheel-godot/WHEEL/Assets/wheel-placeholder/selector.png"):
	set(value):
		selector_texture = value
		if Engine.is_editor_hint():
			_update_node_ui(get_node_or_null("%selector"),underlay_texture)
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
## base score values for the slices
var base_numbers:Array[int] = [-2,-1,1,2]
## slice value multiplier
var slice_values:Array[int] = [1,2,3,4]
## assigns values to directions; format is as follows: [UP,RIGHT,DOWN,LEFT]
var current_value_mappings:Array[int] = [0,90,180,270]
## enum dictating current state of wheel.
enum WheelState {AWAITING_SELECTION,ROTATING,NO_INPUT}
## variable containing current state of wheel.
var _state:WheelState = WheelState.AWAITING_SELECTION
## how many selections have been chosen
var num_selections:int = 0
## a WheelPayload object containing the wheel's value
var _current_value:WheelPayload
## where the selector currently is.
var current_direction:int = 0
## rotation value (in degrees) for the wheel directions. [UP,RIGHT,DOWN,LEFT]
const DIRECTIONS:Array[int] = [0,90,180,270]
## how many selections are allowed; default is 4.
var target_selections:int = 4
#endregion

#region Built-In Functions
#called when the scene is loaded into the tree
func _ready()->void:
	reset() # all the setup is contained in reset
	rotation_finished.connect(end_check) # check if puzzle is completed when rotation is done

# handles input for our minigame
func _unhandled_input(_event: InputEvent) -> void:
	# if space is pressed, confirm selection
	if Input.is_action_just_pressed("ui_accept"):
		process_confirm_input(current_direction)
	# if tab is pressed, rotate the slices
	if Input.is_action_just_pressed("ui_text_completion_replace"):
		rotate_slices()
	
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
#endregion

#region Custom Functions
## processes the input direction and moves the selector to that direction.
func process_direction_input(direction:int)->void:
	if _state != WheelState.AWAITING_SELECTION: return
	selector.rotation_degrees = direction #move our selector to the direction
	_current_value = get_current_wheel_value() #set the current wheel value to our slice and base values
	new_dir_selected.emit() # emit signal that we have moved the selector

## confirms that the current selection has been chosen
func process_confirm_input(direction:int)->void:
	if _state != WheelState.AWAITING_SELECTION: return
		
	for x:Control in %covers.get_children(): 
		if int(round(x.rotation_degrees)) == direction: # rounded because I was getting weird floating point results.
			if x.visible: return 
			
			x.visible = true
			num_selections += 1
			new_dir_chosen.emit(_current_value)
			rotate_slices()

## rotates the slice gimbal +90 degrees
func rotate_slices()->void:
	if _state != WheelState.AWAITING_SELECTION: return
	
	_state = WheelState.ROTATING # set the current wheel state to show it is rotating
	current_value_mappings = _rotate_array(current_value_mappings) # +90 to each of our current value mappings
	_current_value = get_current_wheel_value() # make sure the wheel value is updated
	rotation_started.emit() 
	var tween:Tween = create_tween() # create our tween object we will use for the animation
	tween.set_trans(int(tween_type)) # sets our transition type to our enum
	tween.tween_property(%slice_gimbal, "rotation_degrees",%slice_gimbal.rotation_degrees+90,anim_time) # rotates gimbal for our specified time in anim time
	tween.finished.connect(func(): rotation_finished.emit()) # runs the end_check function when the tween is done

## this function resets the minigame.
func reset()->void:
	randomize() # ensures that godot will randomize the shuffle of the mappings
	%wheel_select.rotation_degrees = 0 # remove this if you don't want the selector to reset up every time
	%slice_gimbal.rotation_degrees = 0 # resets gimbal
	num_selections = 0 # resets number of selections that have been chosen
	for x:Control in covers: x.visible = false # hides the covers
	
	current_value_mappings.shuffle() # chooses a random order for our value mappings
	for x:int in current_value_mappings.size(): # sets the slice rotations to our value mappings
		slices[x].rotation_degrees = current_value_mappings[x]

	for x:int in DIRECTIONS.size(): # assigns the slice value to the direction of the corresponding slice
		for j:int in current_value_mappings.size():
			if DIRECTIONS[x] == current_value_mappings[j]:
				slice_values[x] = x+1

	base_numbers.shuffle() # shuffles base numbers so random wheel segments = a random base number
	_current_value = get_current_wheel_value() # sets our current wheel value
	_state = WheelState.AWAITING_SELECTION # sets the current wheel state to awaiting a selection

## checks if the minigame is finished
func end_check()->void:
	if num_selections == target_selections:
		_state = WheelState.NO_INPUT
		puzzle_finished.emit()
	else:
		_state = WheelState.AWAITING_SELECTION

## returns the wheel value
func get_current_wheel_value()->WheelPayload:
	var wp:WheelPayload = WheelPayload.new()
	for x:int in current_value_mappings.size():
		if current_direction == current_value_mappings[x]:
			wp.base_value = base_numbers[x]
			wp.slice_value = slice_values[x]
			wp.total_value = wp.base_value * wp.slice_value
	return wp
#endregion

#region helper functions
## +90 degrees to each value mapping for rotation; also adjusts base values so they stay the same
func _rotate_array(arr:Array)->Array:
	var a:Array = arr
	var base_number_map:Dictionary = {a[0]:base_numbers[0],a[1]:base_numbers[1],a[2]:base_numbers[2],a[3]:base_numbers[3]} # saves where our base numbers are so we can make sure they match up after rotating
	for x:int in a.size():
		a[x] += 90 # add 90 degrees to each value mapping
		if int(a[x]) == 360: a[x] = 0  # wrap values back to 0
		
		base_numbers[x] = base_number_map.get(a[x]) # makes sure our base numbers stay the same
	return a

# this is all UI stuff. 
func _update_slices_ui(new_textures:Array[Texture2D])->void: 
	for x:int in slices.size(): # this assumes you will have the same amount of covers as slices. idk why you wouldn't.
		#update our slices with the new texture
		slices[x].texture = new_textures[x]
		slices[x].pivot_offset = Vector2(new_textures[x].get_size().x/2,new_textures[x].get_size().y/2)
		slices[x].position = Vector2.ZERO
		slices[x].set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		slices[x].size = new_textures[x].get_size()
		# set our covers to the biggest slice at a modulate and update
		covers[x].texture = new_textures[3]
		covers[x].modulate = Color("000000a8")
		covers[x].pivot_offset = Vector2(Vector2(new_textures[3].get_size().x/2,new_textures[3].get_size().y/2))
		covers[x].position = Vector2.ZERO
		covers[x].set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		covers[x].size = new_textures[3].get_size()
func _update_node_ui(node:Control,new_texture:Texture2D)->void:
	if node==null: return
	
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
