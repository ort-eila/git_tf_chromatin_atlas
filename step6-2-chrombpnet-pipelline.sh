#!/bin/bash
#SBATCH --time=2-00:00:00
#SBATCH --ntasks=1
#SBATCH -G 1
#SBATCH --mem=64GB
#SBATCH --partition=akundaje,owners
#SBATCH --job-name=step62.bpnetPipeline
#SBATCH --output=local_logs/slurm.step62.bpnetPipeline.combined.out
#SBATCH --error=local_logs/slurm.step62.bpnetPipeline.combined.err

# Exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail 
set -x  # Enable verbose command logging

# Initialize Conda for environment activation
eval "$(conda shell.bash hook)"
conda activate chrombpnet

# Load Sherlock modules required to run with GPUs
module load cuda/11.2.0
module load cudnn/8.1.1.33
module load system
module load pango
module load system cairo

# Ensure log directory exists
mkdir -p local_logs

# Get current timestamp and job name
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
JOB_NAME=${SLURM_JOB_NAME}

# Define the CSV file with task details passed as the first argument
CSV_FILE="$1"

# Extract the line corresponding to the SLURM array task ID (1-indexed to 0-indexed)
LINE=$(awk "NR==${SLURM_ARRAY_TASK_ID}" "$CSV_FILE")

# Extract values using awk
SPECIES=$(echo "$LINE" | awk '{print $1}')
ID1=$(echo "$LINE" | awk '{print $2}')
ID2=$(echo "$LINE" | awk '{print $3}')
FOLD_ID=$(echo "$LINE" | awk '{print $4}')
PEAKS_PATH=$(echo "$LINE" | awk '{print $5}')
BAM_PATH=$(echo "$LINE" | awk '{print $6}')
NEGATIVE_FILE=$(echo "$LINE" | awk '{print $7}')

# Define the output directory with date and time included
OUT_DIR="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_model_training/${SPECIES}/${ID1}/${ID2}/${FOLD_ID}/${ID1}_${FOLD_ID}_${JOB_NAME}_${TIMESTAMP}"

# Check if the OUT_DIR already exists and contains the required folders
REQUIRED_FOLDERS=("auxiliary" "evaluation" "logs" "models")

if [ -d "$OUT_DIR" ]; then
    all_exist=true
    for folder in "${REQUIRED_FOLDERS[@]}"; do
        if [ ! -d "$OUT_DIR/$folder" ]; then
            all_exist=false
            break
        fi
    done
    
    if $all_exist; then
        echo "Output directory and required folders already exist: $OUT_DIR. Exiting."
        exit 0
    fi
fi

# Set reference paths based on detected species
if [ "$SPECIES" == "human" ]; then
    FASTA_PATH="./steps_inputs/reference_human/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta"
    CHROM_SIZES_PATH="./steps_inputs/reference_human/GRCh38_EBV.chrom.sizes.tsv"
    BLACK_LIST_BED_PATH="./steps_inputs/reference_human/ENCFF356LFX.bed.gz"
    FOLD_PATH="./steps_inputs/reference_human/human_folds_splits/${FOLD_ID}.json"
    BIAS_MODEL_PATH="./steps_inputs/reference_human/human-fold_0-level1-ENCSR051ECW-cardiomyocyte.h5"
elif [ "$SPECIES" == "mouse" ]; then
    FASTA_PATH="./steps_inputs/reference_mouse/mm10_no_alt_analysis_set_ENCODE.fasta"
    CHROM_SIZES_PATH="./steps_inputs/reference_mouse/mm10_no_alt.chrom.sizes.tsv"
    BLACK_LIST_BED_PATH="./steps_inputs/reference_mouse/boyang/mm10.blacklist.bed.gz"
    FOLD_PATH="./steps_inputs/reference_mouse/mouse_folds_splits/${FOLD_ID}.json"
    BIAS_MODEL_PATH="./steps_inputs/reference_mouse/mouse-fold_0-level1-ENCSR858YSB-adrenal_cortical_cell.h5"
else
    echo "Error: Unsupported species '$SPECIES'."
    exit 1
fi

# Check if all parameters exist
required_files=("$FASTA_PATH" "$CHROM_SIZES_PATH" "$BLACK_LIST_BED_PATH" "$NEGATIVE_FILE" "$FOLD_PATH" "$BIAS_MODEL_PATH" "$BAM_PATH" "$PEAKS_PATH")

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file $file does not exist."
        exit 1
    fi
done

# Create the output directory
mkdir -p "$OUT_DIR"

# Print the output directory
echo "Output Directory: ${OUT_DIR}"

# Run chrombpnet pipeline command
CHROMBP_PIPELINE_COMMAND="chrombpnet pipeline -ibam $BAM_PATH -d ATAC -g $FASTA_PATH -c $CHROM_SIZES_PATH -p $PEAKS_PATH -n $NEGATIVE_FILE -fl $FOLD_PATH -b $BIAS_MODEL_PATH -o $OUT_DIR"

echo "Executing command: $CHROMBP_PIPELINE_COMMAND"

# Execute the chrombpnet pipeline command
eval $CHROMBP_PIPELINE_COMMAND
