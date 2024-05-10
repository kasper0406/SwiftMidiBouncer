import subprocess
import argparse
import csv
import random
import glob
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

def get_silence_cutoff(input: Path):
    command = [ "ffmpeg", "-i", str(input), "-af", "silencedetect=noise=-40dB:d=0.5", "-f", "null", "-" ]
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
        modified_time = row_time - start_time # Updat the time to match
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


def split(in_dir: Path, out_dir: Path, sample_name: str, skip: float, duration: float):
    # print(f"Splitting: skip = {skip}, duration = {duration}")
    split_audio(in_dir / f"{sample_name}.aac", out_dir / f"{sample_name}_%03d.aac", skip, duration)
    split_events(in_dir / f"{sample_name}.csv", out_dir / f"{sample_name}_%03d.csv", skip, duration)


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
        raise ValueError(f"Did not find the same set of labels and samples!, {audio_no_csv}, {csv_no_audio}")

    return list(sorted(audio_names))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='split to split an audio files and midi events into 5 second clips')
    parser.add_argument('input_directory', help='The directory with all the files')
    parser.add_argument('output_directory', help='The directory to write files to')
    args = parser.parse_args()

    def split_sample(sample_name):
        print(f"Converting {sample_name}")
        output_dir = Path(args.output_directory) / sample_name
        output_dir.mkdir(exist_ok = True)

        skip = random.uniform(0, 2.5)
        split(Path(args.input_directory), output_dir, sample_name, skip=skip, duration=4.95)
        return sample_name

    sample_names = load_sample_names(args.input_directory)
    with ThreadPoolExecutor(max_workers=8) as executor:
        converts = executor.map(split_sample, sample_names)
        for converted in converts:
            print(f"Processed {converted}")
