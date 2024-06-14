# SwiftMidiBouncer

SwiftMidiBouncer is a macOS-only utility designed to facilitate the generation and manipulation of MIDI files using Apple's AVFoundation framework and Logic Pro samples. It offers two primary functionalities:

## Features
1. **Generate Plausible MIDI Events:** SwiftMidiBouncer can generate random MIDI events and convert them to audio format.
2. **Transpose MIDI Files:** The tool can also take an existing MIDI file and create transposed versions of the audio.

## Prerequisites
- macOS with Logic Pro installed. SwiftMidiBouncer utilizes samples from Logic Pro and is dependent on the AVFoundation framework, available only on macOS.

## Usage

SwiftMidiBouncer can be operated from the command line as follows:

```bash
./sound_generator {generate_random, from_midi} <output_dir> ...
```

### Commands
- **Generate Random MIDI Events**
  ```bash
  ./sound_generator generate_random <output_dir> <partition_number> <samples_per_instrument>
  ```
  - `partition_number`: The directory number where the samples will be stored.

- **Process MIDI File**
  ```bash
  ./sound_generator from_midi <output_dir> <midi_file>
  ```

## Additional Utilities

For users looking to process data on multiple GPUs, SwiftMidiBouncer includes Python utilities:

- **parallel_generate.py**: Adjust the configuration at the top of the file. This script initiates multiple instances of `sound_generator` to utilize CPU resources fully by generating random MIDI events in parallel.
- **split.py**: Useful after using the `from_midi` command, this script can split the generated CSV and audio files into smaller segments, optimizing them for machine learning model training.

## Dataset Generation

SwiftMidiBouncer has been employed to generate datasets for machine learning projects, notably for the [audio_to_midi_checkpoints](https://github.com/kasper0406/audio-to-midi/) project.

