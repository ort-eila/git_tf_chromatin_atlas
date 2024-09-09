#!/bin/bash

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16GB
#SBATCH --time=01:00:00
#SBATCH --partition=akundaje,owners
#SBATCH --mail-type=all
#SBATCH --mail-user=eila@stanford.edu
#SBATCH --output=local_logs/slurm_step2_samtools_out.combined.out
#SBATCH --error=local_logs/slurm_step2_samtools_err.combined.err

# Set script to exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail

# Load necessary modules
module load biology samtools

# Define the input file path (passed as an argument)
INPUT_FILE="$1"

# Print the first few lines of the input file for debugging
echo "Printing the first 3 lines of the input file ($INPUT_FILE):"
head -n 3 "$INPUT_FILE"

# Extract the specific BAM file path based on SLURM_ARRAY_TASK_ID
BAM_FILE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$INPUT_FILE")
if [ -z "$BAM_FILE" ]; then
  echo "Error: No BAM file found for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}."
  exit 1
fi

echo "Processing BAM file: ${BAM_FILE}"

# Check if the BAM file exists
if [ ! -f "$BAM_FILE" ]; then
  echo "Error: BAM file does not exist: ${BAM_FILE}"
  exit 1
fi


# Print the content of the input file
echo "Bam file '$BAM_FILE' exists. Printing its head:"
head -n 5 "$BAM_FILE"

# Extract ENCSR_ID from the BAM file path (assuming filename format includes ENCSR_ID)
ENCSR_ID=$(basename "$BAM_FILE" | cut -d'_' -f1)

# Define output paths
OUT_DIR=$(dirname "$BAM_FILE")
SORTED_BAM_FILE="${OUT_DIR}/${ENCSR_ID}_sorted.bam"
SORTED_BAM_INDEX="${SORTED_BAM_FILE}.bai"

# Check if the sorted BAM file and its index already exist
if [ -f "$SORTED_BAM_FILE" ]; then
  echo "Sorted BAM file already exists: ${SORTED_BAM_FILE}. Skipping sorting."
else
  # Sort the BAM file
  echo "Sorting BAM file..."
  samtools sort -@ ${SLURM_CPUS_PER_TASK} -o "$SORTED_BAM_FILE" "$BAM_FILE"
  echo "BAM file sorted to ${SORTED_BAM_FILE}"
fi

if [ -f "$SORTED_BAM_INDEX" ]; then
  echo "Index for sorted BAM file already exists: ${SORTED_BAM_INDEX}. Skipping indexing."
else
  # Index the sorted BAM file
  echo "Indexing sorted BAM file..."
  samtools index "$SORTED_BAM_FILE"
  echo "BAM file indexed."
fi

# Optional: Clean up the unsorted BAM file if no longer needed
# Uncomment the line below if you want to remove the original BAM file after sorting
# rm "$BAM_FILE"
# echo "Removed unsorted BAM file."
