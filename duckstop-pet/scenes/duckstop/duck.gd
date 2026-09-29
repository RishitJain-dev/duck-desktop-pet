extends Node2D

@export_group("Movement Settings")
@export var speed: float = 300.0        # Flight speed following the mouse cursor
@export var walk_speed: float = 200.0   # Walking speed along the taskbar
@export var gravity: float = 1200.0      # Falling speed when switching to grounded mode
@export var move_deadzone: float = 75.0  # Pixels away cursor must be before movement starts

@export_group("Animation & Flap Settings")
@export var bob_amplitude: float = 4.0   # Sine wave flap height
@export var bob_frequency: float = 10.0  # Sine wave flap frequency
@export var flip_delay: float = 0.15     # Delay before sprite flips horizontally
@export var floor_offset: float = 43.0   # Height offset to rest on the taskbar

@export_group("Animation Speeds (FPS)")
@export var idle_fps: float = 6.0        # Frame rate when stopped/idle
@export var walk_fps: float = 25.0       # Frame rate when walking on taskbar
@export var chill_fps: float = 6.0       # Frame rate for the chill focus state

@export_group("Rainbow Effect Settings")
@export var rainbow_duration: float = 2.0  # Time in seconds to complete full rainbow cycle

@export_group("Focus Timer Settings")
@export var focus_duration_seconds: float = 1500.0  # 25 minutes (1500s) default
@export var timer_font_size: int = 24               # Font size for live timer label

@onready var duck_sprite: AnimatedSprite2D = $"duck-sprite"
@onready var timer_label: Label = $"timer-label"
@onready var timer: Timer = $timer


var is_flying: bool = true
var is_moving: bool = false
var time_passed: float = 0.0
var flip_timer: float = 0.0
var fall_velocity: float = 0.0

var is_rainbow_active: bool = false
var rainbow_timer: float = 0.0
var default_modulate: Color = Color.WHITE

# Focus Timer States
var is_focus_mode: bool = false
var is_walking_to_corner: bool = false

func _ready() -> void:
	duck_sprite.play("flight")
	default_modulate = duck_sprite.modulate
	
	if timer_label:
		timer_label.visible = false
		timer_label.add_theme_font_size_override("font_size", timer_font_size)
		timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
		timer_label.add_theme_constant_override("outline_size", 4)
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if timer and not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_focus_mode:
			toggle_state()
	
	if event is InputEventKey and event.pressed and not event.echo:
		# Win + Ctrl + J (Rainbow Modulate Effect)
		if event.keycode == KEY_J and event.ctrl_pressed and event.meta_pressed:
			start_rainbow_effect()
			
		# Win + Ctrl + K (Quit Application)
		if event.keycode == KEY_K and event.ctrl_pressed and event.meta_pressed:
			get_tree().quit()
			
		# Win + Ctrl + T (Toggle Focus Timer)
		if event.keycode == KEY_T and event.ctrl_pressed and event.meta_pressed:
			toggle_timer()

func toggle_timer() -> void:
	if is_focus_mode:
		# Reset back to normal mode
		_end_focus_mode()
	else:
		# Start Focus Mode walk
		is_focus_mode = true
		is_flying = false
		is_walking_to_corner = true
		fall_velocity = 0.0

func _start_chill_session() -> void:
	is_walking_to_corner = false
	if timer:
		timer.wait_time = focus_duration_seconds
		timer.one_shot = true
		timer.start()
	
	if timer_label:
		timer_label.visible = true
	
	if duck_sprite.sprite_frames.has_animation("chill"):
		_play_anim_at_fps("chill", chill_fps)

func _on_timer_timeout() -> void:
	_end_focus_mode()

func _end_focus_mode() -> void:
	is_focus_mode = false
	is_walking_to_corner = false
	
	# Stop the countdown
	if timer and not timer.is_stopped():
		timer.stop()
		
	# Hide timer text
	if timer_label:
		timer_label.visible = false
	
	# Return to standard grounded/idle state on taskbar
	if duck_sprite.sprite_frames.has_animation("idle"):
		_play_anim_at_fps("idle", idle_fps)

func _update_timer_label_text() -> void:
	if timer_label and timer:
		var time_left = timer.time_left
		var minutes = int(time_left) / 60
		var seconds = int(time_left) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func start_rainbow_effect() -> void:
	is_rainbow_active = true
	rainbow_timer = 0.0

func _physics_process(delta: float) -> void:
	# --- Rainbow Modulate Effect ---
	if is_rainbow_active:
		rainbow_timer += delta
		var progress = rainbow_timer / rainbow_duration
		
		if progress >= 1.0:
			is_rainbow_active = false
			duck_sprite.modulate = default_modulate
		else:
			duck_sprite.modulate = Color.from_hsv(progress, 1.0, 1.0, default_modulate.a)

	var window_pos = Vector2(DisplayServer.window_get_position())
	var window_size = Vector2(DisplayServer.window_get_size())
	var mouse_screen_pos = Vector2(DisplayServer.mouse_get_position())
	
	var current_screen = DisplayServer.window_get_current_screen()
	var screen_usable_rect = DisplayServer.screen_get_usable_rect(current_screen)
	var floor_y = screen_usable_rect.position.y + screen_usable_rect.size.y - window_size.y + floor_offset
	var bottom_left_x = screen_usable_rect.position.x

	# --- Focus Mode Sequence ---
	if is_focus_mode:
		if window_pos.y < floor_y:
			fall_velocity += gravity * delta
			window_pos.y += fall_velocity * delta
			if window_pos.y >= floor_y:
				window_pos.y = floor_y
				fall_velocity = 0.0
		else:
			window_pos.y = floor_y

		if is_walking_to_corner:
			var x_dist = abs(window_pos.x - bottom_left_x)
			if x_dist > 8.0:
				_update_facing_direction(bottom_left_x, window_pos.x, delta)
				window_pos.x = move_toward(window_pos.x, bottom_left_x, walk_speed * delta)
				
				if duck_sprite.sprite_frames.has_animation("walk"):
					_play_anim_at_fps("walk", walk_fps)
			else:
				window_pos.x = bottom_left_x
				_start_chill_session()
		else:
			_update_timer_label_text()
			if duck_sprite.sprite_frames.has_animation("chill"):
				_play_anim_at_fps("chill", chill_fps)
				
		DisplayServer.window_set_position(Vector2i(window_pos))
		return

	# --- Regular Movement Logic ---
	var target_x = mouse_screen_pos.x - (window_size.x / 2.0)
	var deadzone = move_deadzone if move_deadzone != null else 75.0

	if is_flying:
		time_passed += delta
		var target_pos = mouse_screen_pos - (window_size / 2.0)
		var distance = window_pos.distance_to(target_pos)
		
		if not is_moving and distance > deadzone:
			is_moving = true
		elif is_moving and distance <= 4.0:
			is_moving = false

		if is_moving:
			_update_facing_direction(target_pos.x, window_pos.x, delta)
			window_pos = window_pos.move_toward(target_pos, speed * delta)
			
			if duck_sprite.animation != "flight" or not duck_sprite.is_playing():
				duck_sprite.play("flight")
		else:
			if duck_sprite.is_playing():
				duck_sprite.stop()
		
		var y_offset = sin(time_passed * bob_frequency) * bob_amplitude * delta * 60.0
		window_pos.y += y_offset

	else:
		if window_pos.y < floor_y:
			fall_velocity += gravity * delta
			window_pos.y += fall_velocity * delta
			if window_pos.y >= floor_y:
				window_pos.y = floor_y
				fall_velocity = 0.0
		else:
			window_pos.y = floor_y
			
		var x_distance = abs(window_pos.x - target_x)
		
		if not is_moving and x_distance > deadzone:
			is_moving = true
		elif is_moving and x_distance <= 4.0:
			is_moving = false

		if is_moving:
			_update_facing_direction(target_x, window_pos.x, delta)
			window_pos.x = move_toward(window_pos.x, target_x, walk_speed * delta)
			
			if duck_sprite.sprite_frames.has_animation("walk"):
				_play_anim_at_fps("walk", walk_fps)
			elif duck_sprite.sprite_frames.has_animation("idle"):
				_play_anim_at_fps("idle", walk_fps)
		else:
			if duck_sprite.sprite_frames.has_animation("idle"):
				_play_anim_at_fps("idle", idle_fps)
			elif duck_sprite.is_playing():
				duck_sprite.stop()

	DisplayServer.window_set_position(Vector2i(window_pos))

func _play_anim_at_fps(anim_name: StringName, fps: float) -> void:
	if duck_sprite.sprite_frames.has_animation(anim_name):
		duck_sprite.sprite_frames.set_animation_speed(anim_name, fps)
		if duck_sprite.animation != anim_name or not duck_sprite.is_playing():
			duck_sprite.play(anim_name)

func toggle_state() -> void:
	is_flying = !is_flying
	is_moving = false
	if is_flying:
		fall_velocity = 0.0
		duck_sprite.play("flight")
	else:
		if duck_sprite.sprite_frames.has_animation("idle"):
			_play_anim_at_fps("idle", idle_fps)

func _update_facing_direction(target_x: float, current_x: float, delta: float) -> void:
	var should_flip_left = target_x < current_x
	if should_flip_left != duck_sprite.flip_h:
		flip_timer += delta
		if flip_timer >= flip_delay:
			duck_sprite.flip_h = should_flip_left
			flip_timer = 0.0
	else:
		flip_timer = 0.0
