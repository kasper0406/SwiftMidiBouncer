import subprocess
import argparse
import csv
import random
import glob
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Set

def get_silence_cutoff(input: Path):
    return None

    # Disable after we generate one midi file at a time
    command = [ "ffmpeg", "-i", str(input), "-af", "silencedetect=noise=-30dB:d=1.0", "-f", "null", "-" ]
    result = subprocess.run(command, capture_output=True, text=True)
    lines = result.stderr.split('\n')
    
    last_silence_start = None
    for line in lines:
        if 'silence_start:' in line:
            # Extract the value after 'silence_start:'
            last_silence_start = float(line.split('silence_start:')[1].strip())

    return last_silence_start

def split_audio(input: str, output: str, skip: float, duration: float):
    command = [ "ffmpeg" ]
    silence_cutoff = get_silence_cutoff(input)
    if silence_cutoff is not None:
        command += [ "-t", str(silence_cutoff - skip) ]
    command += [ "-ss", str(skip), "-i", input, "-f", "segment", "-segment_time", str(duration), "-c", "copy", output ]
    subprocess.run(command)

def split_events(input: str, output: str, skip: float, window_duration: float):
    idx = 0
    collected = []
    overflow = []
    prev_overflow = []

    rows = []
    with open(input, mode='r', newline='') as infile:
        reader = csv.reader(infile)
        for row in reader:
            if row[0].startswith('%'):
                continue
            rows.append(row)
    
    for row in sorted(rows, key=lambda x: float(x[0])):
        row_time = float(row[0])
        row_duration = float(row[1])
        if row_time < skip:
            continue
        start_time = idx * window_duration + skip
        split_time = (idx + 1) * window_duration + skip
        # print(f"Time = {row_time}, duration = {row_duration}, skip = {skip}, start_time = {start_time}, split_time = {split_time}")
        if row_time >= split_time:
            idx += 1
            output_filename = str(output) % (idx - 1)
            with open(output_filename, mode='w', newline='') as outfile:
                writer = csv.writer(outfile)
                writer.writerows(prev_overflow + collected)

            collected = []
            prev_overflow = overflow.copy()
            overflow = []
            start_time = idx * window_duration + skip
            split_time = (idx + 1) * window_duration + skip
        elif row_time + row_duration > split_time:
            # If attack time + duration spills over, we will add an event to the next frame as well (mainly to make sure we create)
            # csv files for all audio files
            modified_row = row.copy()
            modified_duration = row_duration - (split_time - row_time)
            modified_row[0] = "0.00"
            modified_row[1] = f"{modified_duration:.2f}"
            overflow.append(modified_row)

        modified_row = row.copy()
        modified_time = row_time - start_time # Update the time to match
        modified_row[0] = f"{modified_time:.2f}"
        collected.append(modified_row)
    
    # Write the remaining output
    output_filename = str(output) % idx
    with open(output_filename, mode='w', newline='') as outfile:
        writer = csv.writer(outfile)
        writer.writerows(prev_overflow + collected)
    
    if len(overflow) != 0:
        output_filename = str(output) % (idx + 1)
        with open(output_filename, mode='w', newline='') as outfile:
            writer = csv.writer(outfile)
            writer.writerows(overflow)

class IncompleteSamples(Exception):
    def __init__(self, message: str, audio_no_csv: Set, csv_no_audio: Set):
        super().__init__(message)
        self.audio_no_csv = audio_no_csv
        self.csv_no_audio = csv_no_audio

def load_sample_names(dataset_dir: Path):
    audio_names = set(
        map(lambda path: path[(len(str(dataset_dir)) + 1):-4], glob.glob(f"{dataset_dir}/**/*.aac", recursive=True))
    )
    label_names = set(
        map(lambda path: path[(len(str(dataset_dir)) + 1):-4], glob.glob(f"{dataset_dir}/**/*.csv", recursive=True))
    )

    if audio_names != label_names:
        audio_no_csv = audio_names - label_names
        csv_no_audio = label_names - audio_names
        raise IncompleteSamples("Did not find the same set of labels and samples",  audio_no_csv, csv_no_audio)

    return list(sorted(audio_names))

def split(in_dir: Path, out_dir: Path, sample_name: str, skip: float, duration: float):
    # print(f"Splitting: skip = {skip}, duration = {duration}")
    output_name = sample_name.split('/')[-1]
    split_audio(in_dir / f"{sample_name}.aac", out_dir / f"{output_name}_%03d.aac", skip, duration)
    split_events(in_dir / f"{sample_name}.csv", out_dir / f"{output_name}_%03d.csv", skip, duration)

    try:
        load_sample_names(out_dir)
    except IncompleteSamples as e:
        # Sometimes a last audio file is produced with decaying notes are being played.
        # We will simply remove this faile.
        if len(e.audio_no_csv) == 1 and len(e.csv_no_audio) == 0:
            # Cleanup
            (left_over_audio,) = e.audio_no_csv
            print(f"Cleaning up left over audio {left_over_audio}.aac")
            Path(out_dir / f"{left_over_audio}.aac").unlink()
        else:
            # Re-reaise e if we are not able to recover
            raise e

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='split to split an audio files and midi events into 5 second clips')
    parser.add_argument('input_directory', help='The directory with all the files')
    parser.add_argument('output_directory', help='The directory to write files to')
    args = parser.parse_args()

    def split_sample(sample_name):
        print(f"Converting {sample_name}")
        output_dir = Path(args.output_directory) / sample_name
        output_dir.mkdir(exist_ok=True, parents=True)

        skip = random.uniform(0, 2.5)
        split(Path(args.input_directory), output_dir, sample_name, skip=skip, duration=4.95)
        return sample_name

    sample_names = load_sample_names(args.input_directory)
    with ThreadPoolExecutor(max_workers=8) as executor:
        converts = executor.map(split_sample, sample_names)
        for converted in converts:
            print(f"Processed {converted}")
