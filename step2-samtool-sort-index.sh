#!/bin/bash

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16GB
#SBATCH --time=01:00:00
#SBATCH --partition=akundaje,owners
#SBATCH --output=local_logs/step2.index.combined.out
#SBATCH --error=local_logs/step2.index.combined.err

# Set script to exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail
set -x 

# Load necessary modules
module load biology samtools

# Define the input file path (passed as an argument)
INPUT_FILE="$1"

# Print the first few lines of the input file for debugging
echo "INPUT_FILE is ($INPUT_FILE)"

# Extract the specific BAM file path based on SLURM_ARRAY_TASK_ID
BAM_FILE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$INPUT_FILE")
if [ -z "$BAM_FILE" ]; then
  echo "Error: No BAM file found for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}."
  exit 1
fi

echo "DEBUG: Processing BAM file: ${BAM_FILE}"

# Check if the BAM file exists
if [ ! -f "$BAM_FILE" ]; then
  echo "Error: BAM file does not exist: ${BAM_FILE}"
  exit 1
fi

# Print the content of the BAM file (header) for debugging
echo "DEBUG: BAM file '$BAM_FILE' exists. Printing its header:"

# Attempt to print the header using samtools, if it fails, delete the BAM file
if ! samtools view -H "$BAM_FILE" &>/dev/null; then
  echo "Error: BAM file '$BAM_FILE' is corrupted or unreadable. Deleting the file."
  rm "$BAM_FILE"
  exit 1
fi

# If the header is successfully printed, continue processing
samtools view -H "$BAM_FILE" | head -n 5

# Extract ENCSR_ID from the BAM file path (assuming filename format includes ENCSR_ID)
ENCSR_ID=$(basename "$BAM_FILE" | cut -d'_' -f1)

# Define output paths
OUT_DIR=$(dirname "$BAM_FILE")
SORTED_BAM_FILE="${OUT_DIR}/${ENCSR_ID}_sorted.bam"
SORTED_BAM_INDEX="${SORTED_BAM_FILE}.bai"

echo "DEBUG: ENCSR_ID is $ENCSR_ID"
echo "DEBUG: Sorted BAM file path: $SORTED_BAM_FILE"
echo "DEBUG: Sorted BAM index file path: $SORTED_BAM_INDEX"

# Check if the sorted BAM file and its index already exist
if [ -f "$SORTED_BAM_FILE" ] && [ -f "$SORTED_BAM_INDEX" ]; then
  echo "Sorted BAM file and index already exist: ${SORTED_BAM_FILE}. Skipping sorting and indexing."
else
  # If any of the files are missing, clean up the incomplete files/folder
  echo "DEBUG: Sorted BAM or index missing, cleaning up incomplete files."

  # Remove the sorted BAM file if it exists (may be partially generated)
  if [ -f "$SORTED_BAM_FILE" ]; then
    echo "DEBUG: Removing incomplete sorted BAM file: $SORTED_BAM_FILE"
    rm "$SORTED_BAM_FILE"
  fi

  # Remove the BAM index if it exists (may be partially generated)
  if [ -f "$SORTED_BAM_INDEX" ]; then
    echo "DEBUG: Removing incomplete BAM index: $SORTED_BAM_INDEX"
    rm "$SORTED_BAM_INDEX"
  fi

  # Optional: remove the original BAM file if it's corrupted or incomplete
  # echo "DEBUG: Removing original BAM file: $BAM_FILE"
  # rm "$BAM_FILE"
  # echo "DEBUG: Original BAM file removed."

  # Sort the BAM file again (if needed)
  echo "DEBUG: Sorting BAM file..."
  samtools sort -@ ${SLURM_CPUS_PER_TASK} -o "$SORTED_BAM_FILE" "$BAM_FILE"
  echo "DEBUG: BAM file sorted to ${SORTED_BAM_FILE}"

  # Index the sorted BAM file
  echo "DEBUG: Indexing sorted BAM file..."
  samtools index "$SORTED_BAM_FILE"
  echo "DEBUG: BAM file indexed."

fi

# Optional: Clean up the unsorted BAM file if no longer needed
# Uncomment the line below if you want to remove the original BAM file after sorting and indexing
# rm "$BAM_FILE"
# echo "DEBUG: Removed unsorted BAM file."
