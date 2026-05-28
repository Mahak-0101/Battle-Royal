extends AudioStreamPlayer

export (float) var wind_strength = 0.9
export (float) var gust_speed = 0.22
export (float) var ambience_volume_db = -25.5

var _generator = null
var _playback = null
var _noise = OpenSimplexNoise.new()
var _phase = 0.0
var _time = 0.0

func _ready():
	_noise.seed = int(OS.get_unix_time())
	_noise.octaves = 3
	_noise.period = 6.5
	_noise.persistence = 0.68

	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = 22050
	_generator.buffer_length = 0.45
	stream = _generator
	volume_db = ambience_volume_db
	play()
	_playback = get_stream_playback()
	set_process(true)

func _process(delta):
	if _playback == null:
		_playback = get_stream_playback()
		if _playback == null:
			return

	_time += delta
	var frames = _playback.get_frames_available()
	if frames <= 0:
		return

	for i in range(frames):
		var t = _time + float(i) / float(_generator.mix_rate)
		var gust = 0.55 + 0.45 * (_noise.get_noise_1d(t * gust_speed + 5.0) * 0.5 + 0.5)
		var low_band = _noise.get_noise_1d(t * 0.8)
		var high_band = _noise.get_noise_1d(t * 3.2 + 31.7)
		var tonal = sin(_phase) * 0.012

		var sample = ((low_band * 0.08) + (high_band * 0.03) + tonal) * gust * wind_strength
		sample = clamp(sample, -0.12, 0.12)
		_playback.push_frame(Vector2(sample, sample))

		_phase += TAU * (52.0 + gust * 18.0) / float(_generator.mix_rate)
