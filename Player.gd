extends CharacterBody3D

signal health_changed(health_value)
var parent

@onready var meshFrente: MeshInstance3D = $frente
@onready var meshCosta: MeshInstance3D = $costa

const chicoFrente: Material = preload("res://Art/blueTeam1.tres")
const chicoCosta: Material = preload("res://Art/blueTeam2.tres")
const veiaFrente: Material = preload("res://Art/redTeam1.tres")
const veiaCosta: Material = preload("res://Art/redTeam2.tres")

@export var offlineMode: bool

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var choose_team_screen = $CanvasLayer/ChooseYourTeam
@onready var player_is_ready: bool = false
@onready var team = 0
var health = 3

const SPEED = 10.0
const JUMP_VELOCITY = 10.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0


	
func _enter_tree():
	print(offlineMode)
	if not offlineMode:
		set_multiplayer_authority(str(name).to_int())
		parent = get_parent()


func _ready():
	if not offlineMode:
		if not is_multiplayer_authority(): return
		camera.current = true
		choose_team_screen.show()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera.current = true
		player_is_ready = true
		#Select_team()
	
		

	
func _unhandled_input(event):
	if not offlineMode:
		if not is_multiplayer_authority() : return
		if not  player_is_ready: return
	
	
	if Input.is_action_just_pressed("blue"):
		var team_tag = 1
		#team_tag.changed.emit(team_tag) 
		#if self.is_in_group("red") or self.is_in_group("neutral"):
		#	remove_from_group("neutral")
		#	remove_from_group("red")
		#	add_to_group("blue")
		#else:
		#	add_to_group("blue")
		#_print_group()
		set_team_tag.rpc(1)
		#_print_tag()
		
	if Input.is_action_just_pressed("red"):
		var team_tag = 2
		#team_tag.changed.emit(team_tag)
		#if self.is_in_group("blue") or self.is_in_group("neutral"):
		#	remove_from_group("neutral")
		#	remove_from_group("blue")
		#	add_to_group("red")
		#else:
		#	add_to_group("blue")
		#_print_group()
		set_team_tag.rpc(2)
		#_print_tag()
		
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		
	if Input.is_action_just_pressed("shoot") and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			if hit_player is CharacterBody3D:
				if hit_player.is_enemy(self):
					print("Enemy detected, attempting to deal damage")
					hit_player.rpc_id(hit_player.get_multiplayer_authority(), "receive_damage")
					
#	if Input.is_action_just_pressed("shoot") \
#			and anim_player.current_animation != "shoot":
#		play_shoot_effects.rpc()
#		if raycast.is_colliding():
#			var hit_player = raycast.get_collider()
#			if hit_player is CharacterBody3D:
#				var other_player = hit_player as CharacterBody3D#hit_player
#				if other_player.has_method("is_enemy"):
#					if other_player.is_enemy(self):
#						print("Enemy detected, attempting to deal damage")
#						other_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
#					else:
#						print("Hit a friendly or neutral player")
					#if other_player.is_enemy(self):
						#print("damaged enemy")
						#other_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	if not player_is_ready: return
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

#@rpc("call_local")
#func receive_damage():
#	health -= 1
#	if health <= 0:
#		health = 3
#		position = Vector3.ZERO
#	health_changed.emit(health)

#@rpc("any_peer")
#func receive_damage():
#	#if not is_multiplayer_authority(): return
#	health -= 1
#	print("Received damage, new health =", health)
#	if health <= 0:
#		health = 3
#		spawn()
#	health_changed.emit(health)
	
@rpc("any_peer")
func receive_damage():
	#if not is_multiplayer_authority(): return
	health -= 1
	print("Received damage, new health =", health)
	if health <= 0:
		health = 3
		spawn()
	health_changed.emit(health)


func is_enemy(other_player: CharacterBody3D) -> bool:
	return other_player.team != team
	#var result = other_player.team != team
	#print("Checking if enemy: other team =", other_player.team, "my team =", team, "result =", result)
	#return result
	
@rpc("call_remote")
func is_enemy_rpc(other_player_id, shooter_id):
	var other_player = get_node("/root").get_node_by_network_id(other_player_id, shooter_id)
	var shooter = get_node("/root").get_node_by_network_id(shooter_id)
	if other_player and shooter and other_player.is_enemy(shooter):
		other_player.receive_damage()

@rpc("call_local")
func set_team_tag(tag):
	#if is_multiplayer_authority():
	var teamtag = tag
	print(teamtag)
	team = teamtag
	print(team)
	print(self.name)
	if teamtag == 1:
		meshFrente.set_surface_override_material(0,chicoFrente)
		meshCosta.set_surface_override_material(0,chicoCosta)
	if teamtag == 2:
		meshFrente.set_surface_override_material(0,veiaFrente)
		meshCosta.set_surface_override_material(0,veiaCosta)
	#team_selected()
	#else:
		#print(tag)
		#team = tag
		#print(team)
	#team_changed.emit(team)
	
func spawn():
	if team == 1:
		set_team_tag.rpc(1)
		if parent.has_method("get_blue_spawn"):
			self.transform.origin = parent.get_blue_spawn().global_position
			#self.transform.basis = parent.get_blue_spawn().global_rotation
	if team == 2:
		set_team_tag.rpc(2)
		if parent.has_method("get_red_spawn"):
			self.transform.origin = parent.get_red_spawn().global_position
			self.rotation_degrees = Vector3(0,180,0)
			
			

func team_seted():
	if is_multiplayer_authority():
		choose_team_screen.hide()
		
	spawn()
		#camera.current = true
	player_is_ready = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		#choose_team_screen.show()

@rpc("call_local")
func ChangeMaterials(mesh: MeshInstance3D, material: Material):
		mesh.set_surface_override_material(0, material)
		
func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")

func _on_blue_team_pressed():
	#if is_multiplayer_authority():
	set_team_tag.rpc(1)
	team_seted()
	set_team_tag.rpc(1)
	
	#if is_multiplayer_authority():
	#	meshFrente.set_surface_override_material(0,chicoFrente)
	#	meshCosta.set_surface_override_material(0,chicoCosta)

func _on_red_team_pressed():
	#if is_multiplayer_authority():
	set_team_tag.rpc(2)
	team_seted()
	set_team_tag.rpc(2)
	#if is_multiplayer_authority():
	#	meshFrente.set_surface_override_material(0,veiaFrente)
	#	meshCosta.set_surface_override_material(0,veiaCosta)
