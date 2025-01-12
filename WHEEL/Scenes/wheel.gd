##
## Hello and welcome to the Persuasion Wheel Game Jam AKA WHEELJAM!
## This code is free to use and distribute for the purposes of WHEELJAM 
## and any games you choose to make with it besides. Please provide attribution
## if you use it outside the jam. :)
##
## This code is also not required for WHEELJAM -- you are free to make your own
## implementation of the wheel, use your own assets, etc.
##
## Everything to make the wheel function is in this single script -- this is a 
## deliberate choice to keep it plug-n-play for the jam. I don't recommend 
## coding like this!
## Have fun and enjoy WHEELJAM!
## Love, Colin & Shane :)
##
class_name Wheel extends Control


##
## Export Variables
##

## our triangles of varying sizes.
@onready var slices:Array[Control] = [%slice1,%slice2,%slice3,%slice4] 

## our covers to indicate that the selection has already been chosen.
@onready var covers:Array[Control] = [%cover_up,%cover_down,%cover_left,%cover_right] 

## a reference to our selector node.
@onready var selector:Control = %selector

## a reference to our slice gimbal.
@onready var slice_gimbal:Control = %slice_gimbal

##
## Internal Variables
##

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

## assigns values to directions; format is as follows: [UP,DOWN,LEFT,RIGHT]
var current_value_mappings:Array[int] = [0,180,270,90]

## how many selections have been chosen
var current_num_selections:int = 0

## how many selections are allowed; default is 4.
var target_selections:int = 4

## rotation value (in degrees) for the wheel directions. [UP,DOWN,LEFT,RIGHT]
const DIRECTIONS:Array[int] = [0,180,270,90]


##
## Signals
##

## emitted when a new direction is selected.
signal new_dir_chosen

## emitted when the gimbal begins to be rotated.
signal rotation_started

## emitted when the gimbal is finished rotating.
signal rotation_finished

## emitted when the puzzle is complete.
signal puzzle_finished

##
## Built-in Functions
##

#called when the scene is loaded into the tree
func _ready()->void:
	reset()
	puzzle_finished.connect(end_check)

# handles input for our minigame
func _unhandled_input(event: InputEvent) -> void:
	
	
	# if up, down, left or right is pressed, process that direction input
	if Input.is_action_just_pressed("ui_up"):
		current_direction=0
		process_direction_input(current_direction,true)
	if Input.is_action_just_pressed("ui_down"):
		current_direction=180
		process_direction_input(current_direction,true)
	if Input.is_action_just_pressed("ui_left"):
		current_direction=270
		process_direction_input(current_direction,true)
	if Input.is_action_just_pressed("ui_right"):
		current_direction=90
		process_direction_input(current_direction,true)
	
	# if tab is pressed, rotate the slices
	if Input.is_action_just_pressed("ui_text_completion_replace"):
		rotate_slices(true)
	
	# if space is pressed, confirm selection
	if Input.is_action_just_pressed("ui_accept"):
		process_confirm_input(current_direction,true)


##
## Custom Functions
##


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

## processes the input direction and moves the selector to that direction.
func process_direction_input(direction:int,debug=false)->void:
	
	#print debug info if enabled
	if debug: print("moving selector to "+str(direction)+" degrees\n")
	
	#move our selector to the direction
	%selector.rotation_degrees = direction


## this function resets the minigame.
func reset()->void:

	# ensures that godot will randomize the shuffle of the mappings
	randomize()
	
	# remove this if you don't want the selector to reset up every time
	%selector.rotation_degrees = 0
	
	# resets gimbal
	%slice_gimbal.rotation_degrees = 0
	
	# hides the covers
	for x in covers: x.visible = false
	
	# shuffles the slice directions
	current_value_mappings.shuffle()
	
	# sets the slice direction to the mapping
	for x in slices.size():
		slices[x].rotation_degrees = current_value_mappings[x]
	
	# sets the current wheel state to awaiting a selection
	current_wheel_state = WheelState.AWAITING_SELECTION

## rotates the slice gimbal +90 degrees
func rotate_slices(debug=false)->void:
	# prints debug info if enabled
	if debug: print("rotating gimbal +90 degrees\n")
	
	# rotates our gimbal using a tween; read tween documentation for controlling the animation.
	var tween = get_tree().create_tween()
	tween.tween_property($slice_gimbal,"rotation_degrees",$slice_gimbal.rotation_degrees+90,0.1)

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
	var wp = WheelPayload.new()
	return wp

##
## Helper Functions
##

## equivelant to a struct, allows us to create wheel payload object and assign values to wheel.
class WheelPayload:
	var base_value:int
	var slice_value:int
	var total_value:int
	
