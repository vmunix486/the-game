extends CharacterBody2D

# --------- VARIABLES ---------- #

@export_category("Player Properties")
@export var move_speed : float = 400
@export var jump_force : float = 600
@export var gravity : float = 30
@export var max_jump_count : int = 2
var jump_count : int = 2

@export_category("Toggle Functions")
@export var double_jump : = false

@export_category("Slide Properties")  
@export var slide_speed : float = 600  
@export var slide_duration : float = 0.5 
@export var slide_cooldown : float = 1.0 

var is_grounded : bool = false
var is_sliding : bool = false  
var slide_timer : float = 0.0  
var slide_cooldown_timer : float = 0.0  

@onready var player_sprite = $AnimatedSprite2D
@onready var spawn_point = %SpawnPoint
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

# --------- BUILT-IN FUNCTIONS ---------- #

func _process(_delta):
	# Update slide timers
	if slide_cooldown_timer > 0: 
		slide_cooldown_timer -= _delta 
	
	# Calling functions
	movement()
	player_animations()
	flip_player()

# --------- CUSTOM FUNCTIONS ---------- #

# Player Movement Code
func movement():
	# Gravity
	if !is_on_floor():
		velocity.y += gravity
	elif is_on_floor():
		jump_count = max_jump_count
	
	handle_jumping()
	handle_sliding() 
	
	# Move Player
	var inputAxis = Input.get_axis("Left", "Right")
	
	# Apply slide speed if sliding, otherwise normal speed
	var current_speed = slide_speed if is_sliding else move_speed  
	velocity = Vector2(inputAxis * current_speed, velocity.y)
	move_and_slide()

# Handle sliding functionality 
func handle_sliding(): 
	if Input.is_action_just_pressed("Slide") and is_on_floor() and slide_cooldown_timer <= 0 and not is_sliding: 
		is_sliding = true  
		slide_timer = slide_duration  
		particle_trails.emitting = true  
	
	if is_sliding:  
		slide_timer -= get_physics_process_delta_time()  
		if slide_timer <= 0:  
			is_sliding = false 
			slide_cooldown_timer = slide_cooldown  
			particle_trails.emitting = false  

# Handles jumping functionality
func handle_jumping():
	if Input.is_action_just_pressed("Jump"):
		if is_on_floor() and !double_jump:
			jump()
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

# Player jump
func jump():
	AudioManager.jump_sfx.play()
	velocity.y = -jump_force

# Handle Player Animations
func player_animations():
	particle_trails.emitting = false if not is_sliding else true  
	
	if is_on_floor():
		if is_sliding:  
			player_sprite.play("Slide") 
		elif abs(velocity.x) > 0:
			particle_trails.emitting = false
			player_sprite.play("Walk", 1.5)
		else:
			player_sprite.play("Idle")
	else:
		player_sprite.play("Jump")

# Flip player sprite based on X velocity
func flip_player():
	if velocity.x < 0: 
		player_sprite.flip_h = true
	elif velocity.x > 0:
		player_sprite.flip_h = false

# Tween Animations
func death_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tween.finished
	global_position = spawn_point.global_position
	await get_tree().create_timer(0.3).timeout
	AudioManager.respawn_sfx.play()
	respawn_tween()

func respawn_tween():
	var tween = create_tween()
	tween.stop(); tween.play()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)

# --------- SIGNALS ---------- #

# Reset the player's position to the current level spawn point if collided with any trap
func _on_collision_body_entered(_body):
	if _body.is_in_group("Traps"):
		AudioManager.death_sfx.play()
		death_particles.emitting = true
		death_tween()
