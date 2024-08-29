#!/bin/bash

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2GB
#SBATCH --time=00:20:00
#SBATCH --partition=akundaje,owners
#SBATCH --mail-type=all
#SBATCH --mail-user=eila@stanford.edu
#SBATCH --output=./local_logs/slurm_step3_peaks_out.combined.out
#SBATCH --error=./local_logs/slurm_step3_peaks_err.combined.err

# Set script to exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail

# Define the input file path (using the argument passed)
INPUT_FILE="$1"

# Define the output directory and create it if it doesn't exist
out_dir="${SCRATCH}/encode_pseudobulks"
mkdir -p "${out_dir}"

# Load necessary modules
module load biology samtools

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' does not exist."
  exit 1
fi

# Print the first few lines of the input file
echo "Input file '$INPUT_FILE' exists. Printing the first 10 lines:"
head -n 10 "$INPUT_FILE"

# Extract the specific line based on SLURM_ARRAY_TASK_ID using awk
LINE=$(awk "NR==${SLURM_ARRAY_TASK_ID}" "$INPUT_FILE")
if [ -z "$LINE" ]; then
  echo "Error: No line found for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}."
  exit 1
fi

# Extract fields from the line
ENCSR_ID=$(echo "$LINE" | awk '{print $1}')
FILE_ID=$(echo "$LINE" | awk '{print $2}')
FILE_NAME=$(echo "$LINE" | awk '{print $3}')
DOWNLOAD_URL=$(echo "$LINE" | awk '{print $4}')

# Define output directories and file paths
OUT_DIR="${SCRATCH}/encode_pseudobulks/${ENCSR_ID}/peaks"
FILE_DIR="${OUT_DIR}/${FILE_ID}"
mkdir -p "${FILE_DIR}"

# Define the output file path
OUTPUT_FILE="${FILE_DIR}/${ENCSR_ID}_${FILE_ID}.bed.gz"

# Check if the file already exists
if [ -f "${OUTPUT_FILE}" ]; then
  echo "File already exists: ${OUTPUT_FILE}. Skipping download."
else
  # Download the file
  echo "Downloading ${FILE_NAME} from ${DOWNLOAD_URL} to ${OUTPUT_FILE}..."
  curl -sRL ${DOWNLOAD_URL} -o ${OUTPUT_FILE}
  echo "Download complete: ${OUTPUT_FILE}"

  # Verify the downloaded file
  if [ -f "${OUTPUT_FILE}" ]; then
    echo "File successfully downloaded and saved to ${OUTPUT_FILE}"
  else
    echo "Error: File not downloaded or saved."
    exit 1
  fi
fi
