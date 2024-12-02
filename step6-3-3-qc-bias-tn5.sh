#!/bin/bash
#SBATCH --job-name=633_motifs_qc_bias_tn5
#SBATCH --output=local_logs/633_motifs_qc_bias_tn5_%A_%a.out
#SBATCH --error=local_logs/633_motifs_qc_bias_tn5_%A_%a.err
#SBATCH --ntasks=1                    # Number of tasks
#SBATCH --cpus-per-task=4             # CPUs per task
#SBATCH --mem=8GB                     # Memory per node
#SBATCH --time=10:00:00               # Time limit (hrs:min:sec)
#SBATCH --partition=akundaje,owners   # Partition name

# Load Conda environment
echo "Loading Conda environment..."
eval "$(conda shell.bash hook)"
conda activate chrombpnet
echo "Conda environment 'chrombpnet' activated."

# Retrieve the input file path from the command-line arguments
input_file="$1"

# Get the current SLURM task ID
task_id=$SLURM_ARRAY_TASK_ID

# Fetch the line corresponding to the SLURM task ID
input_file_path=$(sed -n "${task_id}p" "$input_file")
if [ -z "$input_file_path" ]; then
    echo "Error: No input found for SLURM_ARRAY_TASK_ID=$task_id in $input_file."
    exit 1
fi

echo "Processing SLURM_ARRAY_TASK_ID=$task_id: $input_file_path"

# Extract ENCSR_id and ENCFF_id from the input_file_path
IFS='/' read -r -a path_parts <<< "$input_file_path"

if [ ${#path_parts[@]} -ge 6 ]; then
    ENCSR_id="${path_parts[$(( ${#path_parts[@]} - 7 ))]}"
    ENCFF_id="${path_parts[$(( ${#path_parts[@]} - 6 ))]}"

    echo "ENCSR_id: $ENCSR_id"
    echo "ENCFF_id: $ENCFF_id"
else
    echo "Error: The path_parts array does not have enough elements."
    exit 1  # Exit if there are not enough parts in the path
fi

# Construct directories
base_logo_dir="$GROUP_SCRATCH/eila/encode_pseudobulks/old_encode_pseudobulks_model_training/human/${ENCSR_id}/${ENCFF_id}/fold_0/step62.bpnetPipeline/evaluation/modisco_profile/trimmed_logos/"
output_dir="$GROUP_SCRATCH/eila/encode_pseudobulks/old_encode_pseudobulks_model_training/human/${ENCSR_id}/${ENCFF_id}/fold_0/step62.bpnetPipeline/qc/out_step_6_3_3_motifs_qc_bias_tn5"

echo "Base logo directory set to: $base_logo_dir"
echo "Output directory set to: $output_dir"

# Remove output directory if it already exists
if [ -d "$output_dir" ]; then
    echo "Removing existing output directory: $output_dir"
    rm -rf "$output_dir"
fi

# Run Python script for both 'neg_patterns' and 'pos_patterns'
threshold=80  # Threshold for motif filtering
for group_type in "neg_patterns" "pos_patterns"; do
    echo "Processing $group_type with threshold $threshold..."

    # Prepare the Python command to run the filtering function
    cmd_to_run="
from step6_3_3_filter_motifs_with_tn5_bias import filter_and_copy_patterns
filter_and_copy_patterns('$input_file_path', '$output_dir', '$group_type', '$base_logo_dir', int($threshold))
    "

    # Execute the Python command
    echo "Executing Python command..."
    python -c "$cmd_to_run"
done

echo "Motif QC bias TN5 processing completed."
