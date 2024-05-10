from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from functools import partial
import argparse
import subprocess

executable = "/Users/knielsen/Library/Developer/Xcode/DerivedData/Sound_Generator-gcnkanfkysxnlqgpwolqfsjzwxty/Build/Products/Release/Sound Generator"

def bounce(midi_file: Path, output_directory: Path):
    path = output_directory / midi_file.stem
    path.mkdir(exist_ok=True)

    command = [ executable, "from_midi", str(path), str(midi_file) ]
    proc = subprocess.run(command)

    if proc.returncode != 0:
        print(f"FAILED to conver {midi_file}")

    return midi_file

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='bounce all midi files in a directory into different instrument and transpositions')
    parser.add_argument('input_directory', help='The directory with all the midi files')
    parser.add_argument('output_directory', help='The directory to write the generated audio and csv files to')
    args = parser.parse_args()

    midi_files = Path(args.input_directory).glob("*.mid")
    wrapped_bounce = partial(bounce, output_directory=Path(args.output_directory))

    with ThreadPoolExecutor(max_workers=8) as executor:
        converts = executor.map(wrapped_bounce, midi_files)
        for converted in converts:
            print(f"Processed {converted}")
