#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <input_file> <script_name> <entries_per_job> <max_concurrent_tasks>"
    exit 1
fi

# Assign arguments to variables
INPUT_FILE="$1"
SCRIPT_NAME="$2"
entries_per_job="$3"
max_concurrent_tasks="$4"

# Validate the parameters
if ! [[ "$entries_per_job" =~ ^[0-9]+$ ]] || ! [[ "$max_concurrent_tasks" =~ ^[0-9]+$ ]]; then
    echo "Error: entries_per_job and max_concurrent_tasks must be positive integers."
    exit 1
fi

# Total number of entries
total_entries=$(wc -l < "$INPUT_FILE")
echo "Total entries in input file: $total_entries"

# Calculate the number of job arrays needed
num_arrays=$(( (total_entries + entries_per_job - 1) / entries_per_job ))
echo "Total number of job arrays to be submitted: $num_arrays"

# Submit job arrays
for i in $(seq 0 $((num_arrays - 1))); do
    start=$(( i * entries_per_job + 1 ))
    end=$(( (i + 1) * entries_per_job ))
    
    # Make sure 'end' does not exceed the total number of entries
    if [ $end -gt $total_entries ]; then
        end=$total_entries
    fi

    # Submit the job array with verbose output
    echo "Submitting job array from $start to $end with a maximum of $max_concurrent_tasks concurrent tasks."
    sbatch --verbose --array=${start}-${end}%${max_concurrent_tasks} "$SCRIPT_NAME" "$INPUT_FILE"
done
