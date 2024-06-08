extends CharacterBody3D
enum player_tag{NEUTRAL, RED, BLUE}
signal health_changed(health_value)
@export var offlineMode: bool
@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@export var team_tag: player_tag
var health = 3

const SPEED = 10.0
const JUMP_VELOCITY = 10.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

func _enter_tree():
	print(offlineMode)
	if not offlineMode:
		set_multiplayer_authority(str(name).to_int())


func _ready():
	if not offlineMode:
		if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
func _print_tag():
	print(player_tag.keys()[team_tag])
	
func _unhandled_input(event):
	if not offlineMode:
		if not is_multiplayer_authority(): return
		
	if Input.is_action_just_pressed("neutral"):
		set_team_tag(player_tag.NEUTRAL)
		_print_tag()
		
	if Input.is_action_just_pressed("blue"):
		set_team_tag(player_tag.BLUE)
		_print_tag()
		
	if Input.is_action_just_pressed("red"):
		set_team_tag(player_tag.RED)
		_print_tag()
		
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if Input.is_action_just_pressed("shoot") \
			and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			if hit_player is CharacterBody3D:
				var other_player = hit_player
				if other_player.has_method("is_enemy"):
					if other_player.is_enemy(team_tag):
						print("damaged enemy")
			#var hit_player_tag: int = hit_player.get_type()
			#hit_player_tag = hit_player.current_tag
			#print(PlayerTag.PlayerType.keys()[hit_player_tag])
						other_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
						#hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
			#hit_player.get_type()

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer")
func receive_damage():
	health -= 1
	if health <= 0:
		health = 3
		position = Vector3.ZERO
	health_changed.emit(health)
	
func is_enemy(other_player: player_tag) -> bool:
	print("other player is: " ) 
	print(other_player)
	print("eu sou: ")
	print(team_tag)
	if other_player == team_tag:
		return false
	else:
		return true
	
	
func set_team_tag(tag: player_tag):
	team_tag = tag
	 
func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")
