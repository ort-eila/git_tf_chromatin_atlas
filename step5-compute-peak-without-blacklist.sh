#!/bin/bash

#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --mem=64GB
#SBATCH --partition=akundaje,owners
#SBATCH --job-name=step5NegativesNoPeaksBackground
#SBATCH --output=local_logs/slurm.step5NegativesNoPeaksBackground.combined.out
#SBATCH --error=local_logs/slurm.step5NegativesNoPeaksBackground.combined.err

# TODO: might need less memory
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

# Set reference paths based on detected species
if [ "$species" == "human" ]; then
    FASTA_PATH="./steps_inputs/reference_human/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta"
    # ./steps_inputs/reference_human/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta
    # CHROM_SIZES_PATH=./steps_inputs/reference_human/GRCh38_EBV.chrom.sizes.tsv
    CHROM_SIZES_PATH="./steps_inputs/reference_human/GRCh38_EBV.chrom.sizes.tsv"
    # BLACK_LIST_BED_PATH=./steps_inputs/reference_human/ENCFF356LFX.bed.gz
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

# Define directories and paths
OUT_DIR="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_negative/${species}/${id_1}/${id_2}"
PEAKS_NO_BLACKLIST=$(echo "$LINE" | awk '{print $3}')
echo "$PEAKS_NO_BLACKLIST"
echo "Debug: OUT_DIR is set to: ${OUT_DIR}"
echo "Debug: PEAKS_NO_BLACKLIST is set to: ${PEAKS_NO_BLACKLIST}"

# Check if the PEAKS file exists
if [ ! -f "${PEAKS_NO_BLACKLIST}" ]; then
    echo "Error: The PEAKS_NO_BLACKLIST file ${PEAKS_NO_BLACKLIST} does not exist."
    exit 1
else
    echo "Debug: PEAKS_NO_BLACKLIST file exists."
fi

# Print the contents of the PEAKS_NO_BLACKLIST file
echo "Debug: Checking the contents of the PEAKS_NO_BLACKLIST file: ${PEAKS_NO_BLACKLIST}"
# head -n 5 "${PEAKS_NO_BLACKLIST}"  # Print first 5 lines as a quick check

# Loop through 0 to 4 to create folds
for i in {0..4}; do
    fold=${i}
    FOLD_OUT_DIR=${OUT_DIR}/fold_${fold}
    mkdir -p "$FOLD_OUT_DIR"
    echo "Debug: Processing fold ${fold}. FOLD_OUT_DIR is set to: ${FOLD_OUT_DIR}"

    # Set fold path based on species
    if [ "$species" == "human" ]; then
        FOLD_PATH=./steps_inputs/reference_human/human_folds_splits/fold_${fold}.json
        echo "Debug: Set human FOLD_PATH for fold ${fold}."
    elif [ "$species" == "mouse" ]; then
        FOLD_PATH=./steps_inputs/reference_mouse/mouse_folds_splits/fold_${fold}.json
        echo "Debug: Set mouse FOLD_PATH for fold ${fold}."
    fi
    
    # Check if the output for the current fold already exists
    OUTPUT_FILE="${FOLD_OUT_DIR}/${id_1}_${id_2}_${species}_nonpeaks"

    if [ -f "${OUTPUT_FILE}" ]; then
        echo "Skipping fold ${fold} as output file ${OUTPUT_FILE} already exists."
        continue
    else
        echo "Debug: Output file ${OUTPUT_FILE} does not exist. Proceeding with chrombpnet prep nonpeaks."
    fi

    # Create directory for the current fold if not already present
    mkdir -p "${FOLD_OUT_DIR}"
    echo "Debug: Created ${FOLD_OUT_DIR}."

    # Print detailed debug information for paths and parameters
    echo "Debug: ENCSRID: ${id_1}"
    echo "Debug: fold_number: ${fold}"
    echo "Debug: species: ${species}"
    echo "Debug: Current working directory: $(pwd)"
    
    echo "Debug: Listing contents of OUT_DIR:"
    ls -l "${OUT_DIR}" || echo "Debug: OUT_DIR does not exist or is empty."
    
    echo "Debug: Listing contents of PEAKS_NO_BLACKLIST directory:"
    ls -l "$(dirname "${PEAKS_NO_BLACKLIST}")"
    
    echo "Debug: Listing contents of FASTA_PATH directory:"
    ls -l "$(dirname "${FASTA_PATH}")"
    
    echo "Debug: Listing contents of CHROM_SIZES_PATH directory:"
    ls -l "$(dirname "${CHROM_SIZES_PATH}")"
    
    echo "Debug: Listing contents of FOLD_PATH directory:"
    ls -l "$(dirname "${FOLD_PATH}")"
    
    echo "Debug: Listing contents of BLACK_LIST_BED_PATH directory:"
    ls -l "$(dirname "${BLACK_LIST_BED_PATH}")"

    # Print the chrombpnet command with parameters
    echo "Running command:"
    echo "chrombpnet prep nonpeaks \
        -g ${FASTA_PATH} \
        -p ${PEAKS_NO_BLACKLIST} \
        -c ${CHROM_SIZES_PATH} \
        -f ${FOLD_PATH} \
        -br ${BLACK_LIST_BED_PATH} \
        -o ${OUTPUT_FILE}"

    # Execute the chrombpnet prep nonpeaks command
    chrombpnet prep nonpeaks \
        -g "${FASTA_PATH}" \
        -p "${PEAKS_NO_BLACKLIST}" \
        -c "${CHROM_SIZES_PATH}" \
        -f "${FOLD_PATH}" \
        -br "${BLACK_LIST_BED_PATH}" \
        -o "${OUTPUT_FILE}"
    
    echo "Debug: Completed chrombpnet prep nonpeaks for fold ${fold}."
done

echo "Debug: Script completed successfully."
