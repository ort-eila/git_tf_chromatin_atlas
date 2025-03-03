#!/bin/bash

#SBATCH --time=48:00:00   # Set a 2-day time limit
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16  # Request 8 CPUs per task
#SBATCH --mem=64GB
#SBATCH --partition=akundaje,owners
#SBATCH --job-name=step5NegativesNoPeaksBackground
#SBATCH --output=local_logs/step5.NegativesNoPeaksBackground.combined.out  
#SBATCH --error=local_logs/step5.NegativesNoPeaksBackground.combined.err 

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

id_1=$(echo "${LINE}" | awk '{print $1}')  # Extract first field
organism=$(echo "${LINE}" | awk '{print $2}')  # Extract second field
id_2=$(echo "${LINE}" | awk -F '/' '{print $(NF-1)}')  # Extract second-to-last field
PEAKS_NO_BLACKLIST=$(echo "${LINE}" | awk '{print $3}')  # Extract full path

echo "Debug: Extracted id_1: ${id_1}, id_2: ${id_2}, organism: ${organism}"
echo "Debug: Extracted PEAKS_NO_BLACKLIST: ${PEAKS_NO_BLACKLIST}"

# Convert organism to lowercase
organism=$(echo "$organism" | tr '[:upper:]' '[:lower:]')
echo "Debug: Converted organism to lowercase: ${organism}"

FASTA_PATH=""
CHROM_SIZES_PATH=""
BLACK_LIST_BED_PATH=""
# Enable case-insensitive matching for organism comparison
shopt -s nocasematch

# Set reference paths based on detected organism
if [[ "$organism" == "homo_sapiens" ]]; then
    FASTA_PATH="./steps_inputs/reference_human/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta"
    CHROM_SIZES_PATH="./steps_inputs/reference_human/GRCh38_EBV.chrom.sizes.tsv"
    BLACK_LIST_BED_PATH="./steps_inputs/reference_human/ENCFF356LFX.bed.gz"
    echo "Debug: Set human homo_sapiens reference paths."
elif [[ "$organism" == "mus_musculus" ]]; then
    FASTA_PATH="./steps_inputs/reference_mouse/mm10_no_alt_analysis_set_ENCODE.fasta"
    CHROM_SIZES_PATH="./steps_inputs/reference_mouse/mm10_no_alt.chrom.sizes.tsv"
    BLACK_LIST_BED_PATH="./steps_inputs/reference_mouse/ENCFF547MET.bed.gz"
    echo "Debug: Set mouse reference paths."
else
    echo "Error: Unsupported organism '$organism'."
    exit 1
fi

# Disable case-insensitive matching after use
# shopt -u nocasematch

# Define the output directory based on ID and organism
OUT_DIR="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_negative/${organism}/${id_1}/${id_2}"
echo "Debug: OUT_DIR is set to: ${OUT_DIR}"
echo "Debug: PEAKS_NO_BLACKLIST is set to: ${PEAKS_NO_BLACKLIST}"

# 1. Check if all global input files are available before proceeding
if [ ! -f "${PEAKS_NO_BLACKLIST}" ]; then
    echo "Error: The PEAKS_NO_BLACKLIST file ${PEAKS_NO_BLACKLIST} does not exist. Exiting."
    exit 1
else
    echo "Debug: PEAKS_NO_BLACKLIST file exists."
fi

if [ ! -f "${FASTA_PATH}" ] || [ ! -f "${CHROM_SIZES_PATH}" ] || [ ! -f "${BLACK_LIST_BED_PATH}" ] || [ ! -f "${PEAKS_NO_BLACKLIST}" ]; then
    echo "Error: One or more reference files are missing (FASTA, CHROM_SIZES, BLACK_LIST, or PEAKS_NO_BLACKLIST). Exiting."
    exit 1
else
    echo "Debug: All reference files (FASTA, CHROM_SIZES, BLACK_LIST, PEAKS_NO_BLACKLIST) are available."
fi

# Loop through 0 to 4 to create folds
FOLD_PATH=""
fold=""
for i in {0..4}; do
    fold=${i}
    echo "***1-Debug: fold is ${fold}"
    FOLD_OUT_DIR=${OUT_DIR}/fold_${fold}
    echo "***2-Debug: FOLD_OUT_DIR is ${FOLD_OUT_DIR}"

    # Set fold path based on organism . the double paranthesis for case insensitive
    if [[ "$organism" == "homo_sapiens" ]]; then
        FOLD_PATH=./steps_inputs/reference_human/human_folds_splits/fold_${fold}.json
        echo "***2-1Debug: FOLD_PATH is ${FOLD_PATH}"
    elif [[ "$organism" == "mus_musculus" ]]; then
        FOLD_PATH=./steps_inputs/reference_mouse/mouse_folds_splits/fold_${fold}.json
        echo "***2-2Debug: FOLD_PATH is ${FOLD_PATH}"
    fi

    # 2. Check if fold-specific file exists before creating FOLD_OUT_DIR
    if [ ! -f "${FOLD_PATH}" ]; then
        echo "Error: Fold file ${FOLD_PATH} does not exist. Skipping fold ${fold}."
        echo "***3-Debug: FOLD_PATH is ${FOLD_PATH}"
        continue
    else
        echo "Debug: Fold file ${FOLD_PATH} exists."
    fi

    # Define the base path for the output file
    NONPEAKS_NEGATIVES_FILE_BASE="${FOLD_OUT_DIR}/${id_1}_${id_2}_${organism}_nonpeaks"
    echo "***4-Debug: FOLD_PATH is ${FOLD_PATH}"
    echo "***5-Debug: fold is ${fold}"

    # 3. Skip execution if the specific nonpeaks negatives file already exists
    NONPEAKS_NEGATIVES_FILE="${NONPEAKS_NEGATIVES_FILE_BASE}_negatives.bed"
    if [ -f "${NONPEAKS_NEGATIVES_FILE}" ]; then
        echo "!!!Skipping fold ${fold} as nonpeaks negatives file ${NONPEAKS_NEGATIVES_FILE} already exists."
        echo "***6-Debug: fold is ${fold}"
        continue
    else
        echo "***6-Debug: fold is ${fold}"
        echo "Debug: Nonpeaks negatives file ${NONPEAKS_NEGATIVES_FILE} does not exist. Proceeding."

        if [ -d "${FOLD_OUT_DIR}" ]; then
            echo "Debug7-1: The following files will be removed from ${FOLD_OUT_DIR}:"
            ls -l "${FOLD_OUT_DIR}"
            echo "Debug7-2: Executing rm -rf to clear ${FOLD_OUT_DIR}"
            rm -rf "${FOLD_OUT_DIR}"/*
        else
            echo "Debug8: ${FOLD_OUT_DIR} does not exist. No files to remove."
        fi

        echo "***9-Debug: fold is ${fold}"
        mkdir -p "$FOLD_OUT_DIR"
        echo "Debug: Created FOLD_OUT_DIR: ${FOLD_OUT_DIR}"

        echo "***10-Debug: fold is ${fold}"
        echo "***10-Debug: FOLD_PATH is ${FOLD_PATH}"

        CHROMBPNET_PREP_NONPEAKS="chrombpnet prep nonpeaks -g $FASTA_PATH -p $PEAKS_NO_BLACKLIST -c $CHROM_SIZES_PATH -f $FOLD_PATH -br $BLACK_LIST_BED_PATH -o $NONPEAKS_NEGATIVES_FILE_BASE"

        echo "Executing command: $CHROMBPNET_PREP_NONPEAKS"
        eval $CHROMBPNET_PREP_NONPEAKS

        echo "Debug: Completed chrombpnet prep nonpeaks for fold ${fold}."
    fi
done

echo "Debug: Script completed successfully."
