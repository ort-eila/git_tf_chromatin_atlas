#!/bin/bash

#SBATCH --job-name=step1.bams.download
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4GB
#SBATCH --time=03:30:00
#SBATCH --partition=akundaje,owners
#SBATCH --output=local_logs/step1.download.combined.out
#SBATCH --error=local_logs/step1.download.combined.err

# Load Conda environment
echo "Loading Conda environment..."
eval "$(conda shell.bash hook)"
conda activate chrombpnet
echo "Conda environment 'chrombpnet' activated."

# Define the input file path (using the argument passed)
INPUT_FILE="$1"

# Define the output directory and create it if it doesn't exist
out_dir="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_data"
mkdir -p "${out_dir}"

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file '$INPUT_FILE' does not exist."
  exit 1
fi

# Print the content of the input file
echo "Input file '$INPUT_FILE' exists. Printing the first 3 lines:"
head -n 3 "$INPUT_FILE"

# Extract the specific line based on SLURM_ARRAY_TASK_ID using awk
LINE=$(awk "NR==${SLURM_ARRAY_TASK_ID}" "$INPUT_FILE")
if [ -z "$LINE" ]; then
  echo "Error: No line found for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}."
  exit 1
fi

# Extract ENCSR_ID, download_url, and MD5 checksum using awk
# ENCSR262XGW	https://www.encodeproject.org/files/ENCFF279AJD/@@download/ENCFF279AJD.bam	74e412bd4c230cae5dacc57be2a4fefb
ENCSR_ID=$(echo "${LINE}" | awk '{print $1}')
download_url=$(echo "${LINE}" | awk '{print $2}')
EXPECTED_MD5=$(echo "${LINE}" | awk '{print $3}')
EXPECTED_MD5=$(echo "$EXPECTED_MD5" | tr -d '[:space:]')


# Extract ENCFF_ID from the download_url (last part of the URL, e.g., ENCFF060FCI)
# Extract ENCFF_ID from the download_url (last part of the URL, e.g., ENCFF279AJD)
ENCFF_ID=$(echo "${download_url}" | awk -F'/' '{print $NF}' | sed 's/.bam//')

echo "Extracted ENCFF_ID: ${ENCFF_ID}"
echo "Extracted ENCSR_ID: ${ENCSR_ID}"
echo "Download URL: ${download_url}"
echo "Extracted ENCFF_ID: ${ENCFF_ID}"
echo "Expected MD5 checksum: ${EXPECTED_MD5}"


# Define the output directory for BAM files and create it if it doesn't exist
bam_dir="${out_dir}/bams/${ENCSR_ID}"
mkdir -p "${bam_dir}"
echo "BAM directory created or verified: ${bam_dir}"


# Check if credentials are set
if [ -z "${ACCESS_KEY:-}" ] || [ -z "${SECRET_KEY:-}" ]; then
  echo "Error: ACCESS_KEY or SECRET_KEY is not set. Please set the credentials in your environment."
  exit 1
else
  echo "ACCESS_KEY and SECRET_KEY are set."
fi


# Check if the BAM file already exists
bam_file="${bam_dir}/${ENCFF_ID}_unsorted.bam"
echo "Expected bam_file: ${bam_file}"

if [ -f "$bam_file" ]; then
  echo "BAM file already exists: $bam_file. Proceeding with MD5 check."
else
  # Print the actual curl command for debugging
  echo "DEBUG: Executing the following curl command:"
  echo "curl -sRL -u $ACCESS_KEY:$SECRET_KEY ${download_url} -o ${bam_file}"

  # Download the BAM file using curl
  curl -sRL -u $ACCESS_KEY:$SECRET_KEY "${download_url}" -o "${bam_file}"

  # Check the size of the downloaded file
  BAM_FILE_SIZE=$(stat -c %s "$bam_file")
  echo "Downloaded BAM file size: $BAM_FILE_SIZE bytes"
  
  # Check if the file is suspiciously small (e.g., less than 1000 bytes)
  if [ "$BAM_FILE_SIZE" -lt 1000 ]; then
    echo "Error: BAM file is too small (${BAM_FILE_SIZE} bytes). Deleting the file and exiting."
    rm -f "$bam_file"  # Remove the small BAM file
    exit 1
  fi

  echo "BAM file downloaded to $bam_file"
fi

# Verify the MD5 checksum of the downloaded or existing BAM file
echo "Verifying MD5 checksum..."
# Calculate the MD5 checksum of the downloaded or existing BAM file
# ACTUAL_MD5=$(md5sum "$bam_file" | awk '{print $1}')
ACTUAL_MD5=$(md5sum "$bam_file" | awk '{print $1}' | tr -d '[:space:]')


# Compare the actual MD5 with the expected one
if [ "$ACTUAL_MD5" == "$EXPECTED_MD5" ]; then
  echo "MD5 checksum matches. BAM file is valid."
else
  echo "Error: MD5 checksum does not match for ENCSR_ID: ${ENCSR_ID}, Download URL: ${download_url}!"
  echo "  Expected: $EXPECTED_MD5, but got: $ACTUAL_MD5."
  rm -f "$bam_file"  # Optional: remove the mismatched file
  exit 1
fi

# Verify the BAM file (optional but recommended)
echo "Verifying BAM file..."
if [ -f "$bam_file" ]; then
  echo "BAM file is valid."
else
  echo "Error: BAM file is missing."
  exit 1
fi
