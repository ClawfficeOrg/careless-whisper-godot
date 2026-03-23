extends Control

# Example script demonstrating Careless Whisper speech recognition
# Note: This is a placeholder until the GDExtension is built

# var whisper = preload("res://addons/whisper_cpp/whisper_cpp.gdextension")

@onready var record_button: Button = $VBoxContainer/RecordButton
@onready var output_label: Label = $VBoxContainer/OutputLabel

var is_recording: bool = false

func _ready():
	record_button.pressed.connect(_on_record_button_pressed)
	output_label.text = "Speech recognition addon not yet loaded.\nBuild the GDExtension from godot-whisper-cpp-node branch."

func _on_record_button_pressed():
	if is_recording:
		stop_recording()
	else:
		start_recording()

func start_recording():
	is_recording = true
	record_button.text = "Stop Recording"
	output_label.text = "Recording... (placeholder - GDExtension not built)"
	# TODO: Call whisper.start_recording() when GDExtension is ready

func stop_recording():
	is_recording = false
	record_button.text = "Start Recording"
	output_label.text = "Processing... (placeholder - GDExtension not built)"
	# TODO: Call whisper.stop_recording() and get transcription when GDExtension is ready
