#!/bin/bash
#SBATCH --time=2-00:00:00
#SBATCH --ntasks=1
#SBATCH -G 1
#SBATCH --mem=64GB
#SBATCH --partition=akundaje,owners
#SBATCH --job-name=step5-2-train-chrombpnet

# Get the current date and time in the format YYYYMMDD_HHMMSS
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Add date and time to output and error paths
#SBATCH --output=local_logs/slurm_step5_2_train_chrombpnet_out_${TIMESTAMP}.combined.out
#SBATCH --error=local_logs/slurm_step5_2_train_chrombpnet_err_${TIMESTAMP}.combined.err

# Exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail 

# Initialize Conda for environment activation
eval "$(conda shell.bash hook)"
conda activate chrombpnet

# Sherlock modules required to run with GPUs
module load cuda/11.2.0
module load cudnn/8.1.1.33
module load system
module load pango
module load system cairo

# Define the CSV file with task details passed as the first argument
CSV_FILE="$1"

# Extract the line corresponding to the SLURM array task ID (1-indexed to 0-indexed)
LINE=$(awk "NR==${SLURM_ARRAY_TASK_ID}" "$CSV_FILE")
# Extract values using awk
species=$(echo "$LINE" | awk '{print $1}')
ID1=$(echo "$LINE" | awk '{print $2}')
ID2=$(echo "$LINE" | awk '{print $3}')
fold_id=$(echo "$LINE" | awk '{print $4}')
peaks_path=$(echo "$LINE" | awk '{print $5}')
bam_path=$(echo "$LINE" | awk '{print $6}')
negative_file=$(echo "$LINE" | awk '{print $7}')

# Define the output directory with date and time included
OUT_DIR="${SCRATCH}/encode_pseudobulks_model_training/${species}/${ID1}/${ID2}/${fold_id}_${TIMESTAMP}"

# Set reference paths based on detected species
if [ "$species" == "human" ]; then
    FASTA_PATH="./steps_inputs/reference_human/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta"
    CHROM_SIZES_PATH="./steps_inputs/reference_human/GRCh38_EBV.chrom.sizes.tsv"
    BLACK_LIST_BED_PATH="./steps_inputs/reference_human/ENCFF356LFX.bed.gz"
    FOLD_PATH="./steps_inputs/reference_human/human_folds_splits/"
    BIAS_MODEL_PATH="./steps_inputs/reference_human/human-fold_0-level1-ENCSR051ECW-cardiomyocyte.h5"
elif [ "$species" == "mouse" ]; then
    FASTA_PATH="./steps_inputs/reference_mouse/mm10_no_alt_analysis_set_ENCODE.fasta"
    CHROM_SIZES_PATH="./steps_inputs/reference_mouse/mm10_no_alt.chrom.sizes.tsv"
    BLACK_LIST_BED_PATH="./steps_inputs/reference_mouse/boyang/mm10.blacklist.bed.gz"
    FOLD_PATH="./steps_inputs/reference_mouse/mouse_folds_splits/"
    BIAS_MODEL_PATH="./steps_inputs/reference_mouse/mouse-fold_0-level1-ENCSR858YSB-adrenal_cortical_cell.h5"
else
    echo "Error: Unsupported species '$species'."
    exit 1
fi

# Remove existing output directory if it exists
if [ -d "$OUT_DIR" ]; then
    rm -r "$OUT_DIR"
    echo "Removing ${OUT_DIR}"
fi
mkdir -p "$OUT_DIR"

# Print CSV file and extracted line details
echo "CSV File: ${CSV_FILE}"
echo "Species: ${species}"
echo "ID1: ${ID1}"
echo "ID2: ${ID2}"
echo "Fold ID: ${fold_id}"
echo "Peaks Path: ${peaks_path}"
echo "BAM Path: ${bam_path}"
echo "Negative File Path: ${negative_file}"
echo "Output Directory: ${OUT_DIR}"

# Define and print the chrombpnet command
CHROMBP_COMMAND="chrombpnet train -ibam \"$bam_path\" -d ATAC -g \"$FASTA_PATH\" -c \"$CHROM_SIZES_PATH\" -p \"$peaks_path\" -n \"$negative_file\" -fl \"$FOLD_PATH/${fold_id}.json\" -b \"$BIAS_MODEL_PATH\" -o \"$OUT_DIR\""
echo "Executing command: $CHROMBP_COMMAND"

# Execute the chrombpnet command
eval $CHROMBP_COMMAND
