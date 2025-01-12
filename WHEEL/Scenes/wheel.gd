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
@onready var slices:Array[Control] = [
	%slice1,
	%slice2,
	%slice3,
	%slice4
] 
## our covers to indicate that the selection has already been chosen.
@onready var covers:Array[Control] = [
	%cover_up,
	%cover_down,
	%cover_left,
	%cover_right
] 

@onready var selector:Control = %selector
@onready var slice_gimbal:Control = %slice_gimbal

##
## Internal Variables
##

## enum dictating current state of wheel.
enum WheelState {AWAITING_SELECTION,ROTATING,NO_INPUT} 

## variable containing current state of wheel.
var current_wheel_state:WheelState = WheelState.AWAITING_SELECTION 

var current_direction:int = 0
var base_numbers:Array[int] = [-2,-1,1,2]
var slice_values:Array[int] = [1,2,3,4]

## assigns values to directions; format is as follows: [UP,DOWN,LEFT,RIGHT]
var current_value_mappings:Array[int] = [0,180,270,90]
var current_num_selections:int = 0
var target_selections:int = 4

## rotation value (in degrees) for the wheel directions. [UP,DOWN,LEFT,RIGHT]
const DIRECTIONS:Array[int] = [0,180,270,90]


##
## Signals
##

signal new_dir_chosen
signal rotation_started
signal rotation_finished
signal puzzle_finished

##
## Built-in Functions
##

func _ready()->void:
	reset()
	puzzle_finished.connect(end_check)
	
func _unhandled_input(event: InputEvent) -> void:

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
	
	
	if Input.is_action_just_pressed("ui_text_completion_replace"):
		rotate_slices(true)
		
	if Input.is_action_just_pressed("ui_accept"):
		process_confirm_input(current_direction,true)

##
## Custom Functions
##



func process_confirm_input(direction:int,debug=false)->void:
	#if current_wheel_state != WheelState.AWAITING_SELECTION:
		#return
	for x in %covers.get_children(): # iterate through the covers in the scene
		
		if int(round(x.rotation_degrees)) == direction: # for some reason I was g ett
			
			if debug: print("selecting "+str(direction)+" degrees\n")
			
			if x.visible: return # if the cover is already visible, then it's been selected before.
			x.visible = true # set cover to visible
			current_num_selections += 1 # set the number of selections +=1
			rotate_slices() # rotate the gimbal

func process_direction_input(direction:int,debug=false)->void:
	var dir = 0
	for x in DIRECTIONS.size():
		if direction == DIRECTIONS[x]:
			if debug: print("moving selector to "+str(direction)+" degrees\n")
			dir = DIRECTIONS[x]
	%selector.rotation_degrees = dir

## this function resets the 
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
	
	current_wheel_state = WheelState.AWAITING_SELECTION

func rotate_slices(debug=false)->void:
	if debug: print("rotating gimbal +90 degrees\n")
	var tween = get_tree().create_tween()
	tween.tween_property($slice_gimbal,"rotation_degrees",$slice_gimbal.rotation_degrees+90,0.1)
	

func end_check()->void:
	if current_num_selections == target_selections:
		current_wheel_state = WheelState.NO_INPUT
		puzzle_finished.emit()
	else:
		current_wheel_state = WheelState.AWAITING_SELECTION

func get_current_wheel_value()->WheelPayload:
	var wp = WheelPayload.new()
	return wp
##
## Helper Functions
##


class WheelPayload:
	var base_value:int
	var slice_value:int
	var total_value:int
	
