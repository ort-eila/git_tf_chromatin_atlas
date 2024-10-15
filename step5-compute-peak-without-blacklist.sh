#!/bin/bash

#SBATCH --time=10:00:00   # Set a 10-hour time limit
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8  # Request 8 CPUs per task
#SBATCH --mem=64GB
#SBATCH --partition=akundaje,owners
#SBATCH --job-name=step5NegativesNoPeaksBackground
#SBATCH --output=local_logs/slurm.step5NegativesNoPeaksBackground_%A_%a.out  # Output log per task
#SBATCH --error=local_logs/slurm.step5NegativesNoPeaksBackground_%A_%a.err   # Error log per task


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


    # Set fold path based on species
    if [ "$species" == "human" ]; then
        FOLD_PATH=./steps_inputs/reference_human/human_folds_splits/fold_${fold}.json
        echo "***2-1Debug: FOLD_PATH is ${FOLD_PATH}"
    elif [ "$species" == "mouse" ]; then
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
    # ${ID1}_${ID2}_${species}_nonpeaks_negatives.bed
    NONPEAKS_NEGATIVES_FILE_BASE="${FOLD_OUT_DIR}/${id_1}_${id_2}_${species}_nonpeaks"
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


        # 4. Check if the directory exists before attempting to remove its contents
        if [ -d "${FOLD_OUT_DIR}" ]; then
            echo "Debug7-1: The following files will be removed from ${FOLD_OUT_DIR}:"
            ls -l "${FOLD_OUT_DIR}"
            
            echo "Debug7-2: Executing rm -rf to clear ${FOLD_OUT_DIR}"
            rm -rf "${FOLD_OUT_DIR}"/*
        else
            echo "Debug8: ${FOLD_OUT_DIR} does not exist. No files to remove."
        fi


        echo "***9-Debug: fold is ${fold}"
        # 5. Create the output directory only if input checks are passed and the specific nonpeaks negatives file is missing
        mkdir -p "$FOLD_OUT_DIR"
        echo "Debug: Created FOLD_OUT_DIR: ${FOLD_OUT_DIR}"

        echo "***10-Debug: fold is ${fold}"
        echo "***10-Debug: FOLD_PATH is ${FOLD_PATH}"
        
        # Run the chrombpnet prep nonpeaks command
  
        CHROMBPNET_PREP_NONPEAKS="chrombpnet prep nonpeaks -g $FASTA_PATH -p $PEAKS_NO_BLACKLIST -c $CHROM_SIZES_PATH -f $FOLD_PATH -br $BLACK_LIST_BED_PATH -o $NONPEAKS_NEGATIVES_FILE_BASE "
        
        echo "Executing command: $CHROMBPNET_PREP_NONPEAKS"
        eval $CHROMBPNET_PREP_NONPEAKS
    
        echo "Debug: Completed chrombpnet prep nonpeaks for fold ${fold}."
    fi

        
done

echo "Debug: Script completed successfully."
