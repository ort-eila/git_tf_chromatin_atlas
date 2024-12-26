#!/bin/bash

# Function to print usage information
print_usage() {
    echo "Usage: $0 <input_file> <script_name> <entries_per_job> <max_concurrent_tasks>"
    echo "  <input_file>           : Path to the input file with entries to process."
    echo "  <script_name>          : Path to the script to be run by each job."
    echo "  <entries_per_job>      : Number of entries to process per job."
    echo "  <max_concurrent_tasks> : Max number of concurrent tasks per job array."
    exit 1
}

# Validate number of arguments
if [ "$#" -ne 4 ]; then
    echo "Error: Incorrect number of arguments."
    print_usage
fi

# Assign arguments to variables
INPUT_FILE="$1"
SCRIPT_NAME="$2"
entries_per_job="$3"
max_concurrent_tasks="$4"

# Validate parameters
if ! [[ "$entries_per_job" =~ ^[0-9]+$ ]] || ! [[ "$max_concurrent_tasks" =~ ^[0-9]+$ ]]; then
    echo "Error: entries_per_job and max_concurrent_tasks must be positive integers."
    exit 1
fi

# Calculate total entries and the number of job arrays
total_entries=$(wc -l < "$INPUT_FILE")
num_arrays=$(( (total_entries + entries_per_job - 1) / entries_per_job ))

# SLURM max array size
SLURM_MAX_ARRAY_SIZE=1000

# Submit job arrays
recent_jobs=""
for ((i = 0; i < num_arrays; i++)); do
    start=$((i * SLURM_MAX_ARRAY_SIZE + 1))
    end=$(( (i + 1) * SLURM_MAX_ARRAY_SIZE ))
    end=$((end > total_entries ? total_entries : end))

    # Submit job array
    job_id=$(sbatch --array="${start}-${end}%${max_concurrent_tasks}" "$SCRIPT_NAME" "$INPUT_FILE" | awk '{print $NF}')
    
    # If submission failed, exit
    if [ -z "$job_id" ]; then
        echo "Error: Failed to submit job array for range ${start}-${end}."
        exit 1
    fi

    # Append to job list
    recent_jobs="${recent_jobs:+$recent_jobs,}$job_id"
done

# Function to check job completion
check_job_completion() {
    jobs=$1
    while true; do
        if [ -z "$(squeue --jobs="$jobs" --states=PD,R --noheader)" ]; then
            echo "All tasks for jobs $jobs have completed."
            break
        else
            echo "Waiting for jobs $jobs to complete... Sleeping for 20 minutes."
            sleep 1200
        fi
    done
}

# Wait for jobs to complete
check_job_completion "$recent_jobs"

# Resubmit after completion
echo "Resubmitting job after completion of jobs: $recent_jobs"
sbatch "$0" "$INPUT_FILE" "$SCRIPT_NAME" "$entries_per_job" "$max_concurrent_tasks"
