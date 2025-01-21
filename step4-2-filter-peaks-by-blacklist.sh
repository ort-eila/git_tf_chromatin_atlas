#!/bin/bash

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=2GB
#SBATCH --time=00:20:00
#SBATCH --partition=akundaje,owners
#SBATCH --output=local_logs/step42.filterBackground.out.filter.log
#SBATCH --error=local_logs/step42.filterBackground.err.filter.log

# Set script to exit on errors, undefined variables, or command failures in pipelines
set -euo pipefail
set -x 

# Initialize Conda for environment activation
eval "$(conda shell.bash hook)"
conda activate chrombpnet

# Define file paths
OUTPUT_FOLDER="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_data/peaks_blacklist_filter"

# Check if the input line is provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 '<line>'"
    exit 1
fi

# Define the TXT file with task details passed as the first argument
TXT_FILE="$1"

# Extract the line corresponding to the SLURM array task ID (1-indexed to 0-indexed)
LINE=$(awk "NR==${SLURM_ARRAY_TASK_ID}" "$TXT_FILE")

# Extract values using awk
file_path=$(echo "$LINE" | awk '{print $1}')
organism=$(echo "$LINE" | awk '{print $2}')

# Check if file path and organism were extracted correctly
if [ -z "$file_path" ]; then
    echo "Error: File path is empty!"
    exit 1
fi

if [ -z "$organism" ]; then
    echo "Error: organism is empty!"
    exit 1
fi

echo "DEBUG: Extracted file path: '$file_path'"
echo "DEBUG: Extracted organism: '$organism'"

# Extract ID1 and ID2 from the file path
ID1=$(echo "$file_path" | awk -F'/' '{print $(NF-2)}')  # Extracts the second last directory name
ID2=$(echo "$file_path" | awk -F'/' '{print $(NF-1)}')  # Extracts the last directory name
echo "DEBUG: Extracted ID1: '$ID1'"
echo "DEBUG: Extracted ID2: '$ID2'"

# Define output paths
OUTPUT_FILE="${OUTPUT_FOLDER}/${ID1}/${ID2}/${ID1}_${ID2}_peaks_no_blacklist.bed"
OUTPUT_FILE_GZIP="${OUTPUT_FILE}.gz"
QC_OUTPUT_FILE="${OUTPUT_FOLDER}/${ID1}/${ID2}/${ID1}_${ID2}_peaks_no_blacklist_qc.bed"

# Check if output files already exist to avoid reprocessing
if [[ -f "$OUTPUT_FILE" || -f "$OUTPUT_FILE_GZIP" || -f "$QC_OUTPUT_FILE" ]]; then
    echo "Output files already exist. Skipping processing for ${ID1} ${ID2}."
    exit 0
fi

BLACKLIST_FILE=""
CHROM_SIZES_FILE=""
# Select the appropriate blacklist file based on organism
if [[ "$organism" == "Homo_sapiens" ]]; then
    BLACKLIST_FILE="./steps_inputs/reference_human/ENCFF356LFX.bed.gz"
    echo "DEBUG: human BLACKLIST_FILE is: '$BLACKLIST_FILE'"
    CHROM_SIZES_FILE="./steps_inputs/reference_human/GRCh38_EBV.chrom.sizes.tsv"
    echo "DEBUG: human CHROM_SIZES_FILE is: '$CHROM_SIZES_FILE'"
elif [[ "$organism" == "Mus_musculus" ]]; then
    BLACKLIST_FILE="./steps_inputs/reference_mouse/ENCFF547MET.bed.gz"
    echo "DEBUG: mouse BLACKLIST_FILE is: '$BLACKLIST_FILE'"
    CHROM_SIZES_FILE="./steps_inputs/reference_mouse/mm10_no_alt.chrom.sizes.tsv"
    echo "DEBUG: mouse CHROM_SIZES_FILE is: '$CHROM_SIZES_FILE'"
else
    echo "Error: Unsupported organism '$organism'."
    exit 1
fi
echo "DEBUG: Using blacklist file: '$BLACKLIST_FILE'"

# Define the temporary file path
TEMP_FILE="temp_${ID1}_${ID2}.bed"
echo "DEBUG: Temporary file path: '$TEMP_FILE'"

# Create the necessary subdirectory for the output files
mkdir -p "$(dirname "${OUTPUT_FILE}")"
echo "DEBUG: Created output directory if it did not exist."

# Run bedtools slop
echo "Running bedtools slop for ${ID1} ${ID2}..."
bedtools slop -i "${BLACKLIST_FILE}" -g "${CHROM_SIZES_FILE}" -b 1057 > "${TEMP_FILE}"
echo "DEBUG: bedtools slop completed for ${ID1} ${ID2}. Output saved to ${TEMP_FILE}"

# Display the first few lines of the TEMP_FILE to debug
echo "DEBUG: Preview of TEMP_FILE content:"
head -n 10 "${TEMP_FILE}"

# Run bedtools intersect
echo "Running bedtools intersect for ${ID1} ${ID2}..."
bedtools intersect -v -a "${file_path}" -b "${TEMP_FILE}" > "${OUTPUT_FILE}"
echo "DEBUG: bedtools intersect completed for ${ID1} ${ID2}. Output saved to ${OUTPUT_FILE}"

# Display the first few lines of the OUTPUT_FILE to debug
echo "DEBUG: Preview of OUTPUT_FILE content:"
head -n 10 "${OUTPUT_FILE}"

# Clean up temporary file
rm -f "${TEMP_FILE}"
echo "DEBUG: Cleaned up temporary file: ${TEMP_FILE}"

# Compress the output file
gzip -f "${OUTPUT_FILE}"
echo "DEBUG: Compressed output file: ${OUTPUT_FILE_GZIP}"

# Create a QC report
echo "Creating QC report for ${ID1} ${ID2}..."
# Generate QC difference file to compare input peaks and filtered peaks
echo "Generating QC difference file for ${ID1} ${ID2}..."
bedtools intersect -a "${file_path}" -b "${OUTPUT_FILE}" -wao > "${QC_OUTPUT_FILE}"
echo "DEBUG: QC file generated for ${ID1} ${ID2}. QC saved to ${QC_OUTPUT_FILE}"

# Display the first few lines of QC file to debug
echo "DEBUG: Preview of QC file content:"
head -n 10 "${QC_OUTPUT_FILE}"

# Check if the QC file size is zero
qc_file_size=$(stat -c%s "${QC_OUTPUT_FILE}")
if [[ $qc_file_size -eq 0 ]]; then
    echo "DEBUG: QC file size is zero, indicating no overlaps."
else
    echo "DEBUG: QC file size is $qc_file_size, indicating there are overlaps."
fi

echo "Processing completed for ${ID1} ${ID2}."
