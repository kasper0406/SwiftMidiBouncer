import subprocess
from concurrent.futures import ThreadPoolExecutor
import threading
import sys
import time
import os

executable = "/Users/knielsen/Library/Developer/Xcode/DerivedData/Sound_Generator-gcnkanfkysxnlqgpwolqfsjzwxty/Build/Products/Release/Sound Generator"

dataset = "/Volumes/git/ml/datasets/midi-to-sound/narrowed_keys_5"
workers = 14

partitions = 3
samples_per_partition = 10

class ThreadSafeDict:
    def __init__(self):
        self.lock = threading.Lock()
        self.dict = {}

    def set(self, key, value):
        with self.lock:
            self.dict[key] = value

    def get(self, key):
        with self.lock:
            return self.dict.get(key)
    
    def get_all(self):
        with self.lock:
            return self.dict.copy()

os.makedirs(dataset, exist_ok=True)
progress = ThreadSafeDict()

print(f"Generating a total of {partitions * samples_per_partition} samples...")
def generate_partition(partition):
    global progress

    successful = False
    while not successful:
        program = [executable, dataset, str(partition), str(samples_per_partition)]
        process = subprocess.Popen(program, stdout=subprocess.PIPE, text=True)

        while True:
            output = process.stdout.readline()
            if output == '' and process.poll() is not None:
                break
            if output.strip():
                number_str = output.strip().rstrip('% complete')
                percentage_complete = float(number_str)
                progress.set(partition, percentage_complete)

        successful = process.poll() == 0 # We are successful if the program terminated with code 0
        if not successful:
            print(f"Partition {partition} failed. Trying again...")
            progress.set(partition, 0.0)

    return None

def print_progress_bar(percentage, prefix='', suffix='', decimals=1, length=50, fill='█', printEnd="\r"):
    """
    Call this function to print a progress bar to the console.

    :param iteration: current iteration (Int)
    :param total: total iterations (Int)
    :param prefix: prefix string (Str)
    :param suffix: suffix string (Str)
    :param decimals: positive number of decimals in percent complete (Int)
    :param length: character length of bar (Int)
    :param fill: bar fill character (Str)
    :param printEnd: end character (e.g. "\r", "\r\n") (Str)
    """
    percent = ("{0:." + str(decimals) + "f}").format(100 * (percentage))
    filledLength = int(length * percentage)
    bar = fill * filledLength + '-' * (length - filledLength)
    sys.stdout.write(f'\r{prefix} |{bar}| {percent}% {suffix}')
    sys.stdout.flush()
    # Print New Line on Complete
    if percentage == 1: 
        print()

def print_progress():
    global progress
    print_progress_bar(0.0, prefix='Progress:', suffix='Complete', length=50)
    while True:
        current_progress = progress.get_all().values()
        overall_percentage = (sum(current_progress) / len(current_progress)) / 100
        print_progress_bar(overall_percentage, prefix='Progress:', suffix='Complete', length=50)
        if overall_percentage == 1.0:
            break

        time.sleep(0.5)
        

with ThreadPoolExecutor(max_workers=(workers + 1)) as executor:
    all_partitions = range(partitions)
    for partition in all_partitions:
        progress.set(partition, 0.0)

    status_future = executor.submit(print_progress)
    results = list(executor.map(generate_partition, all_partitions))
