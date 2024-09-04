#!/bin/bash

#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4GB
#SBATCH --partition=akundaje,owners
#SBATCH --job-name=step4_calculate_negatives_or_no_peaks_or_background
#SBATCH --output=local_logs/slurm_step4_negative_out.combined.out
#SBATCH --error=local_logs/slurm_step4_negative_err.combined.err

# Set script to exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail

# Accept the input file as a parameter from execute_sbatch_arrays_on_sherlock.sh
IDS_FILE="$1"

# Convert IDS_FILE to lowercase for consistent checking
IDS_FILE_LOWER=$(echo "$IDS_FILE" | tr '[:upper:]' '[:lower:]')

# Load Conda
source $HOME/miniconda3/etc/profile.d/conda.sh

# Activate the Conda environment
conda activate chrombpnet

# Extract the line corresponding to the SLURM task ID from the input file
LINE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$IDS_FILE")
id_1=$(echo "${LINE}" | cut -d " " -f 1)
id_2=$(echo "${LINE}" | cut -d " " -f 2)

# Determine species from lowercase IDS_FILE name
if [[ "$IDS_FILE_LOWER" == *"human"* ]]; then
    SPECIES="human"
elif [[ "$IDS_FILE_LOWER" == *"mice"* ]]; then
    SPECIES="mice"
else
    echo "Error: Unable to determine species from IDS_FILE ('$IDS_FILE')."
    exit 1
fi

# Define directories and paths
OUT_DIR=${SCRATCH}/encode_pseudobulks_model/${id_1}/negative/
PEAKS=${SCRATCH}/encode_pseudobulks/${id_1}/${id_1}_${id_2}.bed.gz

# Set reference paths based on detected species
if [ "$SPECIES" == "human" ]; then
    FASTA_PATH=./steps_inputs/reference_human/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta
    CHROM_SIZES_PATH=./steps_inputs/reference_human/GRCh38_EBV.chrom.sizes.tsv
    BLACK_LIST_BED_PATH=./steps_inputs/reference_human/ENCFF356LFX.bed.gz
elif [ "$SPECIES" == "mice" ]; then
    FASTA_PATH=./steps_inputs/reference_mice/mm10_no_alt_analysis_set_GCA_000001635.2.fasta
    CHROM_SIZES_PATH=./steps_inputs/reference_mice/mm10.chrom.sizes.tsv
    BLACK_LIST_BED_PATH=./steps_inputs/reference_mice/ENCFF547MET.bed.gz
else
    echo "Error: Unsupported species '$SPECIES'."
    exit 1
fi

# Loop through 0 to 4 to create folds
for i in {0..4}; do
    fold=${i}
    FOLD_OUT_DIR=${OUT_DIR}/fold_${fold}
    
    # Check if output directory for the current fold already exists
    if [ -d "${FOLD_OUT_DIR}" ]; then
        echo "Skipping fold ${fold} as output directory ${FOLD_OUT_DIR} already exists."
        continue
    fi

    # Create directory for the current fold
    mkdir -p ${FOLD_OUT_DIR}
    echo "ENCSRID: ${id_1}"
    echo "fold_number: ${fold}"

    # Define paths specific to the current fold
    FOLD_PATH=./steps_inputs/step4/human_folds/fold_${fold}.json

    # Print current working directory and list files
    echo "Current working directory:"
    pwd
    echo "Contents of OUT_DIR:"
    ls -l ${OUT_DIR}
    echo "Contents of PEAKS directory:"
    ls -l $(dirname ${PEAKS})
    echo "Contents of FASTA_PATH directory:"
    ls -l $(dirname ${FASTA_PATH})
    echo "Contents of CHROM_SIZES_PATH directory:"
    ls -l $(dirname ${CHROM_SIZES_PATH})
    echo "Contents of FOLD_PATH directory:"
    ls -l $(dirname ${FOLD_PATH})
    echo "Contents of BLACK_LIST_BED_PATH directory:"
    ls -l $(dirname ${BLACK_LIST_BED_PATH})

    # Print the chrombpnet command with parameters
    echo "Running command:"
    echo "chrombpnet prep nonpeaks \
        -g ${FASTA_PATH} \
        -p ${PEAKS} \
        -c ${CHROM_SIZES_PATH} \
        -f ${FOLD_PATH} \
        -br ${BLACK_LIST_BED_PATH} \
        -o ${FOLD_OUT_DIR}/${id_1}"

    # Execute the chrombpnet prep nonpeaks command
    chrombpnet prep nonpeaks \
        -g ${FASTA_PATH} \
        -p ${PEAKS} \
        -c ${CHROM_SIZES_PATH} \
        -f ${FOLD_PATH} \
        -br ${BLACK_LIST_BED_PATH} \
        -o ${FOLD_OUT_DIR}/${id_1}
done
