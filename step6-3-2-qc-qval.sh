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

# Define input file path, output directory, and base logo directory
input_file_path="$1"  # The first argument is the input file path
output_dir="$2"       # The second argument is the output directory
base_logo_dir="$3"    # The third argument is the base logo directory

# Define the list of TN5 motifs
bias_motifs=(
    ["tn5_1"]="GCACAGTACAGAGCTG"
    ["tn5_2"]="GTGCACAGTTCTAGAGTGTGCAG"
    ["tn5_3"]="CCTCTACACTGTGCAGAA"
    ["tn5_4"]="GCACAGTTCTAGACTGTGCAG"
    ["tn5_5"]="CTGCACAGTGTAGAGTTGTGC"
)

# Extract identifiers for constructing base_logo_dir if needed
ENCSR_id=$(echo "$input_file_path" | awk -F'/' '{print $(NF-6)}')
ENCFF_id=$(echo "$input_file_path" | awk -F'/' '{print $(NF-5)}')

# Construct the output directory for valid and invalid motifs
valid_output_dir="${output_dir}/valid_motifs"
invalid_output_dir="${output_dir}/invalid_motifs"

# Remove output directories if they already exist
if [ -d "$valid_output_dir" ]; then
    echo "Removing existing valid output directory: $valid_output_dir"
    rm -rf "$valid_output_dir"
fi
if [ -d "$invalid_output_dir" ]; then
    echo "Removing existing invalid output directory: $invalid_output_dir"
    rm -rf "$invalid_output_dir"
fi

# Create the output directories
mkdir -p "$valid_output_dir"
mkdir -p "$invalid_output_dir"

# Run Python script for both 'neg_patterns' and 'pos_patterns' with a loop
for group_type in "neg_patterns" "pos_patterns"; do
    echo "Processing $group_type with bias TN5 search..."

    # Prepare the Python command to run the filtering function
    cmd_to_run="
from filter_and_copy_patterns import filter_and_copy_patterns
filter_and_copy_patterns('$input_file_path', '$output_dir', '$group_type', '$base_logo_dir', ${bias_motifs[@]})
    "

    # Execute the Python command
    echo "Executing Python command..."
    python -c "$cmd_to_run"
done

echo "Motif QC bias TN5 processing completed."
