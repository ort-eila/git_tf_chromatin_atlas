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

# Submit job arrays and capture the last job ID
recent_jobs=""
for i in $(seq 0 $((num_arrays - 1))); do
    start=$(( i * entries_per_job + 1 ))
    end=$(( (i + 1) * entries_per_job ))
    
    # Make sure 'end' does not exceed the total number of entries
    if [ $end -gt $total_entries ]; then
        end=$total_entries
    fi

    # Submit the job array and capture the job ID
    echo "Submitting job array from $start to $end with a maximum of $max_concurrent_tasks concurrent tasks."
    job_id=$(sbatch --verbose --array=${start}-${end}%${max_concurrent_tasks} "$SCRIPT_NAME" "$INPUT_FILE" | awk '{print $NF}')
    
    # Append the job_id to recent_jobs
    if [ -z "$recent_jobs" ]; then
        recent_jobs=$job_id
    else
        recent_jobs="${recent_jobs},$job_id"
    fi
done

# Function to check if all tasks have completed
check_job_completion() {
    jobs=$1

    while true; do
        # Check if any tasks are still pending or running for the job array
        pending_or_running=$(squeue --jobs=$jobs --states=PD,R --noheader)

        if [ -z "$pending_or_running" ]; then
            echo "All tasks for jobs $jobs have completed."
            break
        else
            echo "Waiting for jobs $jobs to complete... Sleeping for 20 minutes."
            sleep 1200  # Sleep for 20 minutes (1200 seconds)
        fi
    done
}

# Wait for all tasks in the job array to complete
check_job_completion "$recent_jobs"

# Resubmit the script once all tasks are completed
if [ -n "$recent_jobs" ]; then
    echo "Resubmitting job after completion of recent jobs: $recent_jobs"
    sbatch "$0" "$INPUT_FILE" "$SCRIPT_NAME" "$entries_per_job" "$max_concurrent_tasks"
fi
