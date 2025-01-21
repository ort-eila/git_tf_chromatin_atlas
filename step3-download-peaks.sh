#!/bin/bash

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2GB
#SBATCH --time=00:50:00
#SBATCH --partition=akundaje,owners
#SBATCH --mail-type=all
#SBATCH --mail-user=eila@stanford.edu
#SBATCH --output=local_logs/step3.peaks.out.combined.out
#SBATCH --error=local_logs/step3.peaks.out.combined.err

# Set script to exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail
set -x

# Load Conda environment
echo "Loading Conda environment..."
eval "$(conda shell.bash hook)"
conda activate chrombpnet
echo "Conda environment 'chrombpnet' activated."

# Define the input file path (using the argument passed)
INPUT_FILE="$1"

# Define the output directory and create it if it doesn't exist. This is the output file as well
out_dir="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_data"
mkdir -p "${out_dir}"

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' does not exist."
  exit 1
fi

# Print the first few lines of the input file
echo "Input file '$INPUT_FILE' exists. Printing the first 3 lines:"
head -n 3 "$INPUT_FILE"

# Extract the specific line based on SLURM_ARRAY_TASK_ID using awk
LINE=$(awk "NR==${SLURM_ARRAY_TASK_ID}" "$INPUT_FILE")  # Skip header row if necessary
if [ -z "$LINE" ]; then
  echo "Error: No line found for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}."
  exit 1
fi

# Debug: Print the line being processed
echo "Processing line: ${LINE}"

# Extract fields from the line (ensure correct columns are targeted)
ENCSR_ID=$(echo "$LINE" | awk -F',' '{print $1}' | sed 's/\/annotations\///' | sed 's/\/$//')
ENCFF_ID=$(echo "$LINE" | awk -F',' '{print $7}')  # Extract from the 7th column (new_bed)
NEW_DOWNLOAD_URL=$(echo "$LINE" | awk -F',' '{print $9}')
NEW_MD5=$(echo "$LINE" | awk -F',' '{print $10}')

# Debug: Print extracted variables
echo "Extracted ENCSR_ID: ${ENCSR_ID}"
echo "Extracted ENCFF_ID: ${ENCFF_ID}"
echo "Extracted NEW_DOWNLOAD_URL: ${NEW_DOWNLOAD_URL}"
echo "Extracted NEW_MD5: ${NEW_MD5}"

# Form the full download URL by concatenating base URL with the relative path
BASE_URL="https://www.encodeproject.org"
FULL_DOWNLOAD_URL="${BASE_URL}${NEW_DOWNLOAD_URL}"

# Debug: Print the full download URL
echo "Constructed FULL_DOWNLOAD_URL: ${FULL_DOWNLOAD_URL}"

# Define output directories and file paths
OUT_DIR="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_data/peaks/${ENCSR_ID}"
FILE_DIR="${OUT_DIR}/${ENCFF_ID}"
mkdir -p "${FILE_DIR}"

# Define the output file path
OUTPUT_FILE="${FILE_DIR}/${ENCSR_ID}_${ENCFF_ID}.bed.gz"

# Check if credentials are set
if [ -z "${ACCESS_KEY:-}" ] || [ -z "${SECRET_KEY:-}" ]; then
  echo "Error: ACCESS_KEY or SECRET_KEY is not set. Please set the credentials in your environment."
  exit 1
fi

# Check if the file already exists
if [ -f "${OUTPUT_FILE}" ]; then
  echo "File already exists: ${OUTPUT_FILE}. Checking MD5..."

  # Verify the MD5 checksum for the existing file
  EXISTING_MD5=$(md5sum "${OUTPUT_FILE}" | awk '{print $1}')
  echo "MD5 of existing file: ${EXISTING_MD5}"

  if [ "$EXISTING_MD5" == "$NEW_MD5" ]; then
    echo "MD5 check passed for existing file: ${ENCFF_ID}. Skipping download."
  else
    echo "Error: MD5 check failed for existing file ${ENCFF_ID}. Redownloading..."
    rm -f "${OUTPUT_FILE}"

    # Redownload the file
    echo "Downloading ${ENCFF_ID} from ${FULL_DOWNLOAD_URL} to ${OUTPUT_FILE}..."
    curl -sRL -u $ACCESS_KEY:$SECRET_KEY "${FULL_DOWNLOAD_URL}" -o "${OUTPUT_FILE}"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to download ${ENCFF_ID} from ${FULL_DOWNLOAD_URL}."
      exit 1
    fi
    echo "Download complete: ${OUTPUT_FILE}"

    # Verify the downloaded file by checking the MD5 hash
    DOWNLOADED_MD5=$(md5sum "${OUTPUT_FILE}" | awk '{print $1}')
    echo "MD5 of downloaded file: ${DOWNLOADED_MD5}"

    if [ "$DOWNLOADED_MD5" == "$NEW_MD5" ]; then
      echo "MD5 check passed for downloaded file: ${ENCFF_ID}."
    else
      echo "Error: MD5 check failed for ${ENCFF_ID}. Deleting the downloaded file."
      rm -f "${OUTPUT_FILE}"
      exit 1
    fi
  fi
else
  # Download the file if it does not exist
  echo "Downloading ${ENCFF_ID} from ${FULL_DOWNLOAD_URL} to ${OUTPUT_FILE}..."
  curl -sRL -u $ACCESS_KEY:$SECRET_KEY "${FULL_DOWNLOAD_URL}" -o "${OUTPUT_FILE}"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to download ${ENCFF_ID} from ${FULL_DOWNLOAD_URL}."
    exit 1
  fi
  echo "Download complete: ${OUTPUT_FILE}"

  # Verify the downloaded file by checking the MD5 hash
  DOWNLOADED_MD5=$(md5sum "${OUTPUT_FILE}" | awk '{print $1}')
  echo "MD5 of downloaded file: ${DOWNLOADED_MD5}"

  if [ "$DOWNLOADED_MD5" == "$NEW_MD5" ]; then
    echo "MD5 check passed for ${ENCFF_ID}."
  else
    echo "Error: MD5 check failed for ${ENCFF_ID}. Deleting the downloaded file."
    rm -f "${OUTPUT_FILE}"
    exit 1
  fi
fi
