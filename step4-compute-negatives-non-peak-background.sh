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

# Load Conda
source /home/users/eila/miniconda3/etc/profile.d/conda.sh

# Activate the Conda environment
conda activate chrombpnet

# Extract the line corresponding to the SLURM task ID from the input file
LINE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$IDS_FILE")
id_1=$(echo "${LINE}" | cut -d " " -f 1)
id_2=$(echo "${LINE}" | cut -d " " -f 2)

# Define directories and paths - this should be passed as input to step 4 and be used as step 5
OUT_DIR=${SCRATCH}/encode_pseudobulks_model/${id_1}/negative/
PEAKS=${SCRATCH}/encode_pseudobulks_model/${id_1}/${id_1}_${id_2}.bed.gz

# INPUT:
FASTA_PATH=./steps_inputs/reference_human/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta
CHROM_SIZES_PATH=./steps_inputs/reference_human/GRCh38_EBV.chrom.sizes.tsv
BED_PATH=./steps_inputs/reference_human/ENCFF356LFX.bed.gz

# Loop through 0 to 4 to create folds
for i in {0..4}; do
    fold=${i}
    mkdir -p ${OUT_DIR}/fold_${fold}
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
    echo "Contents of BED_PATH directory:"
    ls -l $(dirname ${BED_PATH})

    # Print the chrombpnet command with parameters
    echo "Running command:"
    echo "chrombpnet prep nonpeaks \
        -g ${FASTA_PATH} \
        -p ${PEAKS} \
        -c ${CHROM_SIZES_PATH} \
        -f ${FOLD_PATH} \
        -br ${BED_PATH} \
        -o ${OUT_DIR}/fold_${fold}/${id_1}_"

    # Execute the chrombpnet prep nonpeaks command
    chrombpnet prep nonpeaks \
        -g ${FASTA_PATH} \
        -p ${PEAKS} \
        -c ${CHROM_SIZES_PATH} \
        -f ${FOLD_PATH} \
        -br ${BED_PATH} \
        -o ${OUT_DIR}/fold_${fold}/${id_1}_
done
