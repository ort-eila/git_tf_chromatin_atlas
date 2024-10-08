#!/bin/bash

#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --mem=64GB
#SBATCH --partition=akundaje,owners
#SBATCH --job-name=step5NegativesNoPeaksBackground
#SBATCH --output=local_logs/slurm.step5NegativesNoPeaksBackground.combined.out
#SBATCH --error=local_logs/slurm.step5NegativesNoPeaksBackground.combined.err

# Set script to exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail

# Debug: Print all commands before executing
set -x

# Accept the input file as a parameter from execute_sbatch_arrays_on_sherlock.sh
IDS_FILE="$1"
echo "Debug: IDS_FILE is set to: ${IDS_FILE}"

# Load Conda
eval "$(conda shell.bash hook)"
echo "Debug: Conda environment loaded."

# Activate the Conda environment
conda activate chrombpnet
echo "Debug: Activated Conda environment 'chrombpnet'."

# Extract the line corresponding to the SLURM task ID from the input file
LINE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$IDS_FILE")
echo "Debug: Extracted line from IDS_FILE: ${LINE}"

id_1=$(echo "${LINE}" | awk '{print $1}')  # ENCSR449JMK
species=$(echo "${LINE}" | awk '{print $2}')  # human
id_2=$(echo "${LINE}" | awk -F '/' '{print $(NF-1)}')  # Extract the second-to-last field from the path
echo "Debug: Extracted id_1: ${id_1}, id_2: ${id_2}, species: ${species}"

# Convert species to lowercase for consistent checking
species=$(echo "$species" | tr '[:upper:]' '[:lower:]')
echo "Debug: Converted species to lowercase: ${species}"

FASTA_PATH=""
CHROM_SIZES_PATH=""
BLACK_LIST_BED_PATH=""
# Set reference paths based on detected species
if [ "$species" == "human" ]; then
    FASTA_PATH="./steps_inputs/reference_human/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta"
    CHROM_SIZES_PATH="./steps_inputs/reference_human/GRCh38_EBV.chrom.sizes.tsv"
    BLACK_LIST_BED_PATH="./steps_inputs/reference_human/ENCFF356LFX.bed.gz"
    echo "Debug: Set human reference paths."
elif [ "$species" == "mouse" ]; then
    FASTA_PATH="./steps_inputs/reference_mouse/mm10_no_alt_analysis_set_ENCODE.fasta"
    CHROM_SIZES_PATH="./steps_inputs/reference_mouse/mm10_no_alt.chrom.sizes.tsv"
    BLACK_LIST_BED_PATH="./steps_inputs/reference_mouse/ENCFF547MET.bed.gz"
    echo "Debug: Set mouse reference paths."
else
    echo "Error: Unsupported species '$species'."
    exit 1
fi

# Define the output directory based on ID and species
OUT_DIR="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_negative/${species}/${id_1}/${id_2}"
PEAKS_NO_BLACKLIST=$(echo "$LINE" | awk '{print $3}')
echo "Debug: OUT_DIR is set to: ${OUT_DIR}"
echo "Debug: PEAKS_NO_BLACKLIST is set to: ${PEAKS_NO_BLACKLIST}"

# 1. Check if all global input files are available before proceeding
if [ ! -f "${PEAKS_NO_BLACKLIST}" ]; then
    echo "Error: The PEAKS_NO_BLACKLIST file ${PEAKS_NO_BLACKLIST} does not exist. Exiting."
    exit 1
else
    echo "Debug: PEAKS_NO_BLACKLIST file exists."
fi

if [ ! -f "${FASTA_PATH}" ] || [ ! -f "${CHROM_SIZES_PATH}" ] || [ ! -f "${BLACK_LIST_BED_PATH}" ]; then
    echo "Error: One or more reference files are missing (FASTA, CHROM_SIZES, or BLACK_LIST). Exiting."
    exit 1
else
    echo "Debug: All reference files (FASTA, CHROM_SIZES, BLACK_LIST) are available."
fi

# Loop through 0 to 4 to create folds
for i in {0..4}; do
    fold=${i}
    FOLD_OUT_DIR=${OUT_DIR}/fold_${fold}

    # Set fold path based on species
    if [ "$species" == "human" ]; then
        FOLD_PATH=./steps_inputs/reference_human/human_folds_splits/fold_${fold}.json
    elif [ "$species" == "mouse" ]; then
        FOLD_PATH=./steps_inputs/reference_mouse/mouse_folds_splits/fold_${fold}.json
    fi

    # 2. Check if fold-specific file exists before creating FOLD_OUT_DIR
    if [ ! -f "${FOLD_PATH}" ]; then
        echo "Error: Fold file ${FOLD_PATH} does not exist. Skipping fold ${fold}."
        continue
    else
        echo "Debug: Fold file ${FOLD_PATH} exists."
    fi

    # Define the base path for the output file
    NONPEAKS_NEGATIVES_FILE_BASE="${FOLD_OUT_DIR}/${id_1}_${id_2}_${species}_nonpeaks"

    # 3. Skip execution if the specific nonpeaks negatives file already exists
    NONPEAKS_NEGATIVES_FILE="${NONPEAKS_NEGATIVES_FILE_BASE}.bed"
    if [ -f "${NONPEAKS_NEGATIVES_FILE}" ]; then
        echo "Skipping fold ${fold} as nonpeaks negatives file ${NONPEAKS_NEGATIVES_FILE} already exists."
        continue
    else
        echo "Debug: Nonpeaks negatives file ${NONPEAKS_NEGATIVES_FILE} does not exist. Proceeding."
    fi

    # 4. Create the output directory only if input checks are passed and the specific nonpeaks negatives file is missing
    mkdir -p "$FOLD_OUT_DIR"
    echo "Debug: Created FOLD_OUT_DIR: ${FOLD_OUT_DIR}"

    # Run the chrombpnet prep nonpeaks command using NONPEAKS_NEGATIVES_FILE_BASE
    chrombpnet prep nonpeaks \
        -g "${FASTA_PATH}" \
        -p "${PEAKS_NO_BLACKLIST}" \
        -c "${CHROM_SIZES_PATH}" \
        -f "${FOLD_PATH}" \
        -br "${BLACK_LIST_BED_PATH}" \
        -o "${NONPEAKS_NEGATIVES_FILE_BASE}"

    echo "Debug: Completed chrombpnet prep nonpeaks for fold ${fold}."

    # Rename the generated file with a .bed extension
    mv "${NONPEAKS_NEGATIVES_FILE_BASE}" "${NONPEAKS_NEGATIVES_FILE}"
    echo "Debug: Moved ${NONPEAKS_NEGATIVES_FILE_BASE} to ${NONPEAKS_NEGATIVES_FILE}."
done

echo "Debug: Script completed successfully."
