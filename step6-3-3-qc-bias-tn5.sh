#!/bin/bash
#SBATCH --job-name=633_motifs_qc_bias_tn5
#SBATCH --output=local_logs/633_motifs_qc_bias_tn5.out
#SBATCH --error=local_logs/633_motifs_qc_bias_tn5.err
#SBATCH --ntasks=1                    # Number of tasks
#SBATCH --cpus-per-task=4             # CPUs per task
#SBATCH --mem=16GB                    # Memory per node
#SBATCH --time=02:00:00               # Time limit (hrs:min:sec)
#SBATCH --partition=akundaje,owners   # Partition name

# Load Conda environment
echo "Loading Conda environment..."
eval "$(conda shell.bash hook)"
conda activate chrombpnet
echo "Conda environment 'chrombpnet' activated."

# Define input file path and threshold
input_file_path="$1"  # The first argument is the input file path
threshold=80         # The threshold for motif filtering - for the BLAST similarity value

# Extract identifiers for constructing base_logo_dir
ENCSR_id=$(echo "$input_file_path" | awk -F'/' '{print $(NF-6)}')
ENCFF_id=$(echo "$input_file_path" | awk -F'/' '{print $(NF-5)}')

# Construct base_logo_dir using $GROUP_SCRATCH
base_logo_dir="$GROUP_SCRATCH/eila/encode_pseudobulks/old_encode_pseudobulks_model_training/human/${ENCSR_id}/${ENCFF_id}/fold_0/step62.bpnetPipeline/evaluation/modisco_profile/trimmed_logos/"

echo "Base logo directory set to: $base_logo_dir"

# Define output directory based on the input file's directory
output_dir="$GROUP_SCRATCH/eila/encode_pseudobulks/old_encode_pseudobulks_model_training/human/${ENCSR_id}/${ENCFF_id}/fold_0/step62.bpnetPipeline/qc/out_step_6_3_3_motifs_qc_bias_tn5"

echo "Output directory set to: $output_dir"

# Remove output directory if it already exists
if [ -d "$output_dir" ]; then
    echo "Removing existing output directory: $output_dir"
    rm -rf "$output_dir"
fi

# Run Python script for both 'neg_patterns' and 'pos_patterns'
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
