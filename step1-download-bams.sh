#!/bin/bash

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4GB
#SBATCH --time=00:35:00
#SBATCH --partition=akundaje,owners
#SBATCH --mail-type=all
#SBATCH --mail-user=eila@stanford.edu
#SBATCH --output=local_logs/slurm_step1_download_bams_out.combined.out
#SBATCH --error=local_logs/slurm_step1_download_bams_err.combined.err

# Define the input file path (using the argument passed)
INPUT_FILE="$1"

# Define the output directory and create it if it doesn't exist
out_dir="${SCRATCH}/encode_pseudobulks_data"
mkdir -p "${out_dir}"  # This command creates the output directory if it doesn't exist

# Set script to exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail

# Load necessary modules
module load biology samtools

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

# Extract ENCSR_ID and download_url using awk
ENCSR_ID=$(echo "${LINE}" | awk '{print $1}')
download_url=$(echo "${LINE}" | awk '{print $4}')
echo "Extracted ENCSR_ID: ${ENCSR_ID}"
echo "Download URL: ${download_url}"

# Define the output directory for BAM files and create it if it doesn't exist
bam_dir="${out_dir}/${ENCSR_ID}/bam"
mkdir -p "${bam_dir}"  # This command creates the BAM directory if it doesn't exist
echo "BAM directory created or verified: ${bam_dir}"

# Export credentials as environment variables
echo "Extracted ACCESS_KEY: ${ACCESS_KEY}"
echo "Extracted SECRET_KEY: ${SECRET_KEY}"

echo "Credentials exported (ensure these are not sensitive before sharing logs)."

# Check if the BAM file already exists
if [ -f "${bam_dir}/${ENCSR_ID}_unsorted.bam" ]; then
  echo "BAM file already exists: ${bam_dir}/${ENCSR_ID}_unsorted.bam"
else
  # Download the BAM file
  echo "Downloading BAM file from ${download_url}..."
  curl -sRL -u ${ACCESS_KEY}:${SECRET_KEY} ${download_url} -o "${bam_dir}/${ENCSR_ID}_unsorted.bam"
  echo "BAM file downloaded to ${bam_dir}/${ENCSR_ID}_unsorted.bam"
fi

# Verify the BAM file
echo "Verifying BAM file..."
if [ -f "${bam_dir}/${ENCSR_ID}_unsorted.bam" ]; then
  echo "BAM file is valid."
else
  echo "Error: BAM file is missing."
  exit 1
fi
