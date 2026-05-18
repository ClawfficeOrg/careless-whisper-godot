## history_entry.gd
## A single row in the HistoryPanel: timestamp label + transcription text.
## Instantiated by HistoryPanel for each recorded transcription.
extends HBoxContainer

class_name HistoryEntry

@onready var _timestamp_label: Label = $TimestampLabel
@onready var _transcript_label: RichTextLabel = $TranscriptLabel


## Populate this row with transcription text and a formatted timestamp string.
func set_data(text: String, timestamp: String) -> void:
	_timestamp_label.text = timestamp
	_transcript_label.text = text
