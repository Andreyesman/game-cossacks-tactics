extends Node

const SETTINGS_FILE := "user://settings.cfg"

const TRACKS: Dictionary = {
	"map": "res://assets/audio/music/map_theme.wav",
	"battle": "res://assets/audio/music/battle_theme.wav"
}

const SFX: Dictionary = {
	"hit_melee": "res://assets/audio/sfx/hit_melee.wav",
	"hit_ranged": "res://assets/audio/sfx/hit_ranged.wav",
	"death": "res://assets/audio/sfx/death.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"buy": "res://assets/audio/sfx/buy.wav",
	"level_up": "res://assets/audio/sfx/level_up.wav",
	"heal": "res://assets/audio/sfx/heal.wav",
	"hire": "res://assets/audio/sfx/hire.wav",
	"notification": "res://assets/audio/sfx/notification.wav"
}

const SFX_POOL_SIZE := 5
const CROSSFADE_DURATION := 1.5
const STOP_FADE_DURATION := 1.0
const DEFAULT_MUSIC_VOLUME := 0.7
const DEFAULT_SFX_VOLUME := 0.8
const DB_SILENT := -80.0

var _music_players: Array[AudioStreamPlayer] = []
var _sfx_pool: Array[AudioStreamPlayer] = []
var _active_music_idx: int = 0
var _current_track_key: String = ""
var _music_volume: float = DEFAULT_MUSIC_VOLUME
var _sfx_volume: float = DEFAULT_SFX_VOLUME
var _fade_tween: Tween


func _ready() -> void:
	_ensure_audio_buses()
	_create_players()
	_load_settings()


func play_music(track_key: String) -> void:
	if track_key == _current_track_key:
		return
	var path: String = TRACKS.get(track_key, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("AudioManager: музичний трек не знайдено: %s" % track_key)
		return

	var stream := load(path) as AudioStream
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()

	var prev_player: AudioStreamPlayer = _music_players[_active_music_idx]
	_active_music_idx = 1 - _active_music_idx
	var next_player: AudioStreamPlayer = _music_players[_active_music_idx]

	next_player.stream = stream
	next_player.volume_db = DB_SILENT
	next_player.play()
	_current_track_key = track_key

	_fade_tween = create_tween().set_parallel(true)
	if prev_player.playing:
		_fade_tween.tween_property(prev_player, "volume_db", DB_SILENT, CROSSFADE_DURATION)
	_fade_tween.tween_property(next_player, "volume_db", 0.0, CROSSFADE_DURATION)
	var stopped := prev_player
	_fade_tween.finished.connect(func(): stopped.stop(), CONNECT_ONE_SHOT)


func stop_music() -> void:
	var active_player: AudioStreamPlayer = _music_players[_active_music_idx]
	if not active_player.playing:
		return
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_current_track_key = ""
	_fade_tween = create_tween()
	_fade_tween.tween_property(active_player, "volume_db", DB_SILENT, STOP_FADE_DURATION)
	_fade_tween.finished.connect(func(): active_player.stop(), CONNECT_ONE_SHOT)


func play_sfx(sfx_key: String) -> void:
	var path: String = SFX.get(sfx_key, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("AudioManager: SFX не знайдено: %s" % sfx_key)
		return
	var stream := load(path) as AudioStream
	var player := _get_free_sfx_player()
	if player == null:
		return
	player.stream = stream
	player.play()


func set_music_volume(linear: float) -> void:
	_music_volume = clampf(linear, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, _to_db(_music_volume))
	_save_settings()


func set_sfx_volume(linear: float) -> void:
	_sfx_volume = clampf(linear, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, _to_db(_sfx_volume))
	_save_settings()


func get_music_volume() -> float:
	return _music_volume


func get_sfx_volume() -> float:
	return _sfx_volume


func _ensure_audio_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _create_players() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		player.finished.connect(_on_music_player_finished.bind(player))
		_music_players.append(player)
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)


func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	return null


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		_music_volume = config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
		_sfx_volume = config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	# застосувати гучність без зайвого збереження
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, _to_db(_music_volume))
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, _to_db(_sfx_volume))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)  # зберегти існуючі значення (locale тощо)
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.save(SETTINGS_FILE)


func _to_db(linear: float) -> float:
	return DB_SILENT if linear <= 0.0 else linear_to_db(linear)


func _on_music_player_finished(player: AudioStreamPlayer) -> void:
	if player == _music_players[_active_music_idx]:
		player.play()
