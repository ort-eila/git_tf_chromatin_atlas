#!/bin/bash

# Define base path
# negative_base_path="$SCRATCH/encode_pseudobulks_negative"
negative_base_path="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_negative/"

# Define the output file
output_file="./steps_inputs/step5/extracted_paths.txt"

# Create the output directory if it doesn't exist
mkdir -p "$(dirname "$output_file")"

# Clear the output file if it exists to remove any existing information
> "$output_file"

# Loop through the directories to extract the relevant information
for negative_path in $(ls -d ${negative_base_path}/*/*/*/fold_*); do
    # Extract the species, ID1, ID2, and fold_id from the path
    species=$(echo "${negative_path}" | awk -F'/' '{print $(NF-3)}')  # Correct index for species
    ID1=$(echo "${negative_path}" | awk -F'/' '{print $(NF-2)}')      # Correct index for ID1
    ID2=$(echo "${negative_path}" | awk -F'/' '{print $(NF-1)}')      # Correct index for ID2
    fold_id=$(echo "${negative_path}" | awk -F'/' '{print $(NF)}')    # Extract the full fold_id

    # Construct the paths
    peaks_path="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_data/peaks/${ID1}/${ID2}/${ID1}_${ID2}.bed.gz"
    bam_path="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_data/bams/${ID1}/${ID1}_sorted.bam"
    negative_file="${negative_path}/${ID1}_${ID2}_${species}_negatives.bed"

    # Check if the paths exist and print errors if they don't
    if [[ ! -f "${peaks_path}" ]]; then
        echo "Error: Missing peaks file ${peaks_path}"
        continue
    fi

    if [[ ! -f "${bam_path}" ]]; then
        echo "Error: Missing BAM file ${bam_path}"
        continue
    fi

    if [[ ! -f "${negative_file}" ]]; then
        echo "Error: Missing negative file ${negative_file}"
        continue
    fi

    # Write the extracted information to the file with space delimiters
    echo "${species} ${ID1} ${ID2} ${fold_id} ${peaks_path} ${bam_path} ${negative_file}" >> "$output_file"

done

echo "File has been generated at: ${output_file}"
