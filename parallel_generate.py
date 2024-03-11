import subprocess
from concurrent.futures import ThreadPoolExecutor
from functools import partial

executable = "/Users/knielsen/Library/Developer/Xcode/DerivedData/Sound_Generator-gcnkanfkysxnlqgpwolqfsjzwxty/Build/Products/Release/Sound Generator"

dataset = "v2"
workers = 4

partitions = 10
samples_per_partition = 10

print(f"Generating a total of {partitions * samples_per_partition} samples...")
def generate_partition(partition):
    program = [executable, dataset, str(partition), str(samples_per_partition)]
    result = subprocess.run(program, stdout=subprocess.PIPE, text=True)
    print(result.stdout)

    return result

with ThreadPoolExecutor(max_workers=workers) as executor:
    all_partitions = range(partitions)
    results = list(executor.map(generate_partition, all_partitions))

print("Results:")
print(results)
