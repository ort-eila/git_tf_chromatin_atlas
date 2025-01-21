#!/bin/bash

# Validate the number of arguments passed to the script
if [ "$#" -ne 4 ]; then
    echo "Error: Incorrect number of arguments."
    echo "Usage: $0 <input_file> <script_name> <entries_per_job> <max_concurrent_tasks>"
    exit 1
fi

# Assign arguments to descriptive variables
INPUT_FILE="$1"
SCRIPT_NAME="$2"
entries_per_job="$3"
max_concurrent_tasks="$4"

# Validate that entries_per_job and max_concurrent_tasks are positive integers
if ! [[ "$entries_per_job" =~ ^[0-9]+$ ]] || ! [[ "$max_concurrent_tasks" =~ ^[0-9]+$ ]]; then
    echo "Error: entries_per_job and max_concurrent_tasks must be positive integers."
    exit 1
fi

# Count the total number of lines (tasks) in the input file
total_entries=$(wc -l < "$INPUT_FILE")

# Calculate the number of job arrays required
num_arrays=$(( (total_entries + entries_per_job - 1) / entries_per_job ))

# SLURM maximum array size (default is 1000; adjust if needed)
MAX_SLURM_ARRAY_SIZE=1000

# Initialize a variable to store the list of recently submitted job IDs
recent_jobs=""

# Loop through each required array to submit jobs
for ((i = 0; i < num_arrays; i++)); do
    # Define the task range for the current job array
    start=$((i * entries_per_job + 1))
    end=$(( (i + 1) * entries_per_job ))
    end=$((end > total_entries ? total_entries : end))

    # Break down range if it exceeds SLURM's max array size
    if ((end - start + 1 > MAX_SLURM_ARRAY_SIZE)); then
        sub_start=$start
        while ((sub_start <= end)); do
            sub_end=$((sub_start + MAX_SLURM_ARRAY_SIZE - 1))
            sub_end=$((sub_end > end ? end : sub_end))
            echo "Submitting job array for range ${sub_start}-${sub_end}%${max_concurrent_tasks}"
            job_id=$(sbatch --array="${sub_start}-${sub_end}%${max_concurrent_tasks}" "$SCRIPT_NAME" "$INPUT_FILE" | awk '{print $NF}')
            if [ -z "$job_id" ]; then
                echo "Error: Failed to submit job array for range ${sub_start}-${sub_end}."
                exit 1
            fi
            recent_jobs="${recent_jobs:+$recent_jobs,}$job_id"
            sub_start=$((sub_end + 1))
        done
    else
        echo "Submitting job array for range ${start}-${end}%${max_concurrent_tasks}"
        job_id=$(sbatch --array="${start}-${end}%${max_concurrent_tasks}" "$SCRIPT_NAME" "$INPUT_FILE" | awk '{print $NF}')
        if [ -z "$job_id" ]; then
            echo "Error: Failed to submit job array for range ${start}-${end}."
            exit 1
        fi
        recent_jobs="${recent_jobs:+$recent_jobs,}$job_id"
    fi
done

# Output the list of running jobs
echo "Jobs $recent_jobs are running..."
