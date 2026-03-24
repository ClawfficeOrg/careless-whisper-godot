# Mic Level Meter

The Mic Level Meter (`MicMeter.tscn`) is a UI component that visualizes microphone input levels in real-time. It displays audio levels as a progress bar, changing color based on the RMS level (low = green, medium = yellow, high = red).

## How It Works

1. **Audio Input:** The script captures microphone audio input using Godot's `AudioServer`.
2. **RMS Calculation:** The RMS level of the input is calculated to determine amplitude.
3. **Color-Coded Feedback:** The progress bar dynamically updates, with green for low levels, yellow for medium, and red for high.

## Adding to a Scene

1. Add `MicMeter.tscn` as a child node to your scene.
2. Position it at the top of the window for accessibility.

The following code shows a typical setup:

```gdscript
var mic_meter = preload("res://scenes/ui/MicMeter.tscn").instantiate()
add_child(mic_meter)
```

Ensure the scene has microphone permission enabled to retrieve real-time input.

## File Breakdown

### `MicMeter.tscn`
A Godot scene containing:
- A `Control` node as the root.
- A `ProgressBar` node that visually represents audio input levels.

### `MicMeter.gd`
A script that:
- Captures audio input.
- Updates the progress bar's value and modulate color based on input level.
- Highlights different input ranges with distinct colors.

### Example Scene

Here is how it appears when integrated:
- `MicMeter` visualizes the audio level dynamically.
- Changing colors help the user discern loudness visually.

```text
[ Quiet ] ---------------> [ Medium ] ---------------> [ Loud ]
```

## Notes
- `AudioServer` is used to query real-time microphone data.
- Proper error handling for audio inputs ensures stability.

For customization, modify `MicMeter.gd` as needed.