#!/bin/bash
#SBATCH --job-name=632_motifs_qc_tomtom
#SBATCH --output=local_logs/632_motifs_qc_tomtom_bias_tn5_%A_%a.out
#SBATCH --error=local_logs/632_motifs_qc_tomtom_bias_tn5_%A_%a.err
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

# Extract ENCSR_id and ENCFF_id from the input_file_path
IFS='/' read -r -a path_parts <<< "$input_file_path"

if [ ${#path_parts[@]} -ge 6 ]; then
    SPECIES="${path_parts[$(( ${#path_parts[@]} - 8))]}"
    ENCSR_id="${path_parts[$(( ${#path_parts[@]} - 7 ))]}"
    ENCFF_id="${path_parts[$(( ${#path_parts[@]} - 6 ))]}"
    
    echo "SPECIES: $SPECIES"
    echo "ENCSR_id: $ENCSR_id"
    echo "ENCFF_id: $ENCFF_id"
else
    echo "Error: The path_parts array does not have enough elements."
    exit 1  # Exit if there are not enough parts in the path
fi

# Set directories
base_logo_dir="$GROUP_SCRATCH/eila/encode_pseudobulks/old_encode_pseudobulks_model_training/${SPECIES}/${ENCSR_id}/${ENCFF_id}/fold_0/step62.bpnetPipeline/evaluation/modisco_profile/trimmed_logos/"
output_dir="$GROUP_SCRATCH/eila/encode_pseudobulks/old_encode_pseudobulks_model_training/${SPECIES}/${ENCSR_id}/${ENCFF_id}/fold_0/step62.bpnetPipeline/qc/out_step_6_3_2_tomtom"

echo "Base logo directory set to: $base_logo_dir"
echo "Output directory set to: $output_dir"

# Remove existing output directory if it exists
if [ -d "$output_dir" ]; then
    echo "Removing existing output directory: $output_dir"
    rm -rf "$output_dir"
fi

# Path to provided motifs.meme file
motifs_meme_file="./steps_inputs/step6_3/motifs.meme"

# Threshold for motif filtering
threshold=80  # Adjust as necessary

# Run Python script for both 'neg_patterns' and 'pos_patterns'
for group_type in "neg_patterns" "pos_patterns"; do
    echo "Processing $group_type with threshold $threshold..."

    # Prepare the Python command to run the TOMTOM comparison
    cmd_to_run="
from step6_3_2_filter_motifs_with_TOMTOM_tn5_bias import filter_and_copy_patterns
filter_and_copy_patterns('$input_file_path', '$output_dir', '$group_type', '$base_logo_dir', int($threshold), '$motifs_meme_file')
    "

    # Execute the Python command
    echo "Executing Python command..."
    python -c "$cmd_to_run"
done

echo "Motif QC bias TN5 processing completed."
