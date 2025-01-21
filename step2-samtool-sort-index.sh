#!/bin/bash

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=16GB
#SBATCH --time=04:00:00
#SBATCH --partition=akundaje,owners
#SBATCH --output=local_logs/step2.samtools.combined.out
#SBATCH --error=local_logs/step2.samtools.combined.err

# Exit on errors, undefined variables, or pipeline failures
set -euo pipefail
set -x

# Load necessary modules
module load biology samtools

# Define the input file path (passed as an argument)
INPUT_FILE="$1"

# Print debug message for input file
echo "DEBUG: INPUT_FILE is ($INPUT_FILE)"

# Extract the specific BAM file path based on SLURM_ARRAY_TASK_ID
BAM_FILE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$INPUT_FILE")
if [ -z "$BAM_FILE" ]; then
  echo "ERROR: No BAM file found for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}."
  exit 1
fi

echo "DEBUG: Processing BAM file: ${BAM_FILE}"

# Check if the BAM file exists
if [ ! -f "$BAM_FILE" ]; then
  echo "ERROR: BAM file does not exist: ${BAM_FILE}"
  exit 1
fi

# Check BAM file integrity using samtools quickcheck
echo "DEBUG: Verifying BAM file: $BAM_FILE"
if ! samtools quickcheck "$BAM_FILE"; then
  echo "ERROR: BAM file '$BAM_FILE' is corrupted or unreadable. Exiting."
  exit 1
fi


ENCFF_ID=$(basename "$BAM_FILE" | cut -d'_' -f1)
echo "DEBUG: ENCFF_ID is $ENCFF_ID"

# Define output paths
OUT_DIR=$(dirname "$BAM_FILE")
SORTED_BAM_FILE="${OUT_DIR}/${ENCFF_ID}_sorted.bam"
SORTED_BAM_INDEX="${SORTED_BAM_FILE}.bai"
echo "DEBUG: Sorted BAM file path: $SORTED_BAM_FILE"
echo "DEBUG: Sorted BAM index file path: $SORTED_BAM_INDEX"

# Check if sorted BAM and index already exist
if [ -f "$SORTED_BAM_FILE" ] && [ -f "$SORTED_BAM_INDEX" ]; then
  echo "DEBUG: Sorted BAM file and index already exist. Skipping processing."
else
  # Clean up partially generated files
  [ -f "$SORTED_BAM_FILE" ] && rm "$SORTED_BAM_FILE" && echo "DEBUG: Removed incomplete sorted BAM file."
  [ -f "$SORTED_BAM_INDEX" ] && rm "$SORTED_BAM_INDEX" && echo "DEBUG: Removed incomplete BAM index."

  # Check if output directory exists and is writable
  echo "DEBUG: Checking output directory permissions"
  if [ ! -d "$OUT_DIR" ]; then
    echo "ERROR: Output directory does not exist: $OUT_DIR"
    exit 1
  elif [ ! -w "$OUT_DIR" ]; then
    echo "ERROR: Output directory is not writable: $OUT_DIR"
    exit 1
  fi

  # Sort the BAM file
  echo "DEBUG: Sorting BAM file..."
  echo "Executing: samtools sort -@ ${SLURM_CPUS_PER_TASK} -o \"$SORTED_BAM_FILE\" \"$BAM_FILE\""
  if ! samtools sort -@ "${SLURM_CPUS_PER_TASK}" -o "$SORTED_BAM_FILE" "$BAM_FILE" 2>&1 | tee sorted_bam.log; then
    echo "ERROR: Sorting BAM file failed for $BAM_FILE. Exiting."
    exit 1
  fi
  echo "DEBUG: BAM file sorted successfully to $SORTED_BAM_FILE."

  # Index the sorted BAM file
  echo "DEBUG: Indexing sorted BAM file..."
  echo "Executing: samtools index \"$SORTED_BAM_FILE\""
  if ! samtools index "$SORTED_BAM_FILE" 2>&1 | tee index_bam.log; then
    echo "ERROR: Indexing sorted BAM file failed for $SORTED_BAM_FILE. Exiting."
    exit 1
  fi
  echo "DEBUG: BAM file indexed successfully: ${SORTED_BAM_FILE}.bai"
fi

# Uncomment to clean up original BAM file if no longer needed
# rm "$BAM_FILE"
# echo "DEBUG: Removed original BAM file: $BAM_FILE"
