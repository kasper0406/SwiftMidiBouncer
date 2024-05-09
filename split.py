import subprocess
import argparse
import csv
import random
import glob
from pathlib import Path

def get_silence_cutoff(input: Path):
    command = [ "ffmpeg", "-i", str(input), "-af", "silencedetect=noise=-30dB:d=0.5", "-f", "null", "-" ]
    result = subprocess.run(command, capture_output=True, text=True)
    lines = result.stderr.split('\n')
    
    last_silence_start = None
    for line in lines:
        if 'silence_start:' in line:
            # Extract the value after 'silence_start:'
            last_silence_start = float(line.split('silence_start:')[1].strip())

    return last_silence_start

def split_audio(input: str, output: str, skip: float, duration: float):
    total_skip = skip + 0.0469 # Hack for adding two audio frames to make the events line up
    command = [ "ffmpeg" ]
    silence_cutoff = get_silence_cutoff(input)
    if silence_cutoff is not None:
        command += [ "-t", str(silence_cutoff - total_skip) ]
    command += [ "-ss", str(total_skip), "-i", input, "-f", "segment", "-segment_time", str(duration), "-c", "copy", output ]
    subprocess.run(command)

def split_events(input: str, output: str, skip: float, duration: float):
    idx = 0
    collected = []

    with open(input, mode='r', newline='') as infile:
        reader = csv.reader(infile)
        for row in reader:
            if row[0].startswith('%'):
                continue
            time = float(row[0])
            if time < skip:
                continue
            start_time = idx * duration + skip
            split_time = (idx + 1) * duration + skip
            # TODO: Consider handling the case where the note attack time + duration splits oover start_time and split_time
            if time >= split_time:
                idx += 1
                output_filename = str(output) % (idx - 1)
                with open(output_filename, mode='w', newline='') as outfile:
                    writer = csv.writer(outfile)
                    writer.writerows(collected)

                collected = []
                start_time = idx * duration + skip
                split_time = (idx + 1) * duration + skip

            modified_row = row
            modified_time = float(modified_row[0]) - start_time # Updat the time to match
            modified_row[0] = f"{modified_time:.2f}"
            collected.append(modified_row)
        
        # Write the remaining output
        output_filename = str(output) % idx
        with open(output_filename, mode='w', newline='') as outfile:
            writer = csv.writer(outfile)
            writer.writerows(collected)


def split(in_dir: Path, out_dir: Path, sample_name: str, skip: float, duration: float):
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

    sample_names = load_sample_names(args.input_directory)
    for sample_name in sample_names:
        print(f"Converting {sample_name}")
        output_dir = Path(args.output_directory) / sample_name
        output_dir.mkdir(exist_ok = True)

        skip = random.uniform(0, 2.5)
        split(Path(args.input_directory), output_dir, sample_name, skip=skip, duration=4.95)
