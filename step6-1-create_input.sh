#!/bin/bash

# Define the log file
log_file="./local_logs/step6.1.txt"

# Create the log directory if it doesn't exist
mkdir -p "$(dirname "$log_file")"

# Redirect both stdout and stderr to the log file, without printing to the console
exec > "$log_file" 2>&1

# Define base path
negative_base_path="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_negative"

# Define the output files
output_file="./steps_inputs/step6/chrombpnet_pipeline_extracted_paths.txt"
fold0_output_file="./steps_inputs/step6/chrombpnet_pipeline_extracted_paths_fold_0.txt"

# Create the output directories if they don't exist
echo "Creating output directory: $(dirname "$output_file")"
mkdir -p "$(dirname "$output_file")"

# Clear the output files if they exist to remove any existing information
echo "Clearing existing contents of output files if they exist..."
> "$output_file"
> "$fold0_output_file"

# Debug message before starting the loop
echo "Starting the extraction process. Base path for negatives: ${negative_base_path}"

# Loop through the directories to extract the relevant information
for negative_path in $(ls -d ${negative_base_path}/*/*/*/fold_*); do

    echo "-----------------------------"
    echo "Processing negative path: ${negative_path}"  # Debug message for current negative path

    # List all files under the negative path
    echo "Listing all files under ${negative_path}:"
    ls -lh "${negative_path}"

    
    # Extract the species, ID1, ID2, and fold_id from the path
    species=$(basename $(dirname $(dirname $(dirname "${negative_path}"))))
    ID1=$(basename $(dirname $(dirname "${negative_path}")))
    ID2=$(basename $(dirname "${negative_path}"))
    fold_id=$(basename "${negative_path}")

    # Debug messages for the extracted values
    echo "Extracted species: ${species}"
    echo "Extracted ID1: ${ID1}"
    echo "Extracted ID2: ${ID2}"
    echo "Extracted fold_id: ${fold_id}"

    # Construct the paths
    filtered_peaks_path="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_data/peaks_blacklist_filter/${ID1}/${ID2}/${ID1}_${ID2}_peaks_no_blacklist.bed.gz"
    bam_path="${GROUP_SCRATCH}/${USER}/encode_pseudobulks/encode_pseudobulks_data/bams/${ID1}/${ID1}_sorted.bam"
    negative_file="${negative_path}/${ID1}_${ID2}_${species}_nonpeaks_negatives.bed"

    # Debug messages for constructed paths
    echo "Constructed filtered_peaks_path: ${filtered_peaks_path}"
    echo "Constructed BAM path: ${bam_path}"
    echo "Constructed negative file path: ${negative_file}"

    # Check if the paths exist and print errors if they don't
    if [[ ! -f "${filtered_peaks_path}" ]]; then
        echo "Error: Missing peaks file ${filtered_peaks_path}"
        continue
    fi

    if [[ ! -f "${bam_path}" ]]; then
        echo "Error: Missing BAM file ${bam_path}"
        continue
    fi

    # Check if the negative file exists, and remove the folder if it doesn't
    if [[ ! -f "${negative_file}" ]]; then
        echo "Error: Missing negative file ${negative_file}"

        # Remove the directory containing the missing negative file. 
        # !!!Dont uncomment the rm command while step 5 is running and creating the negative files!!!!
        echo "Removing directory due to missing negative file: ${negative_path}"
        echo "Debug: The following files will be removed from ${negative_path}:"
        echo "********************************"
        ls -l "${negative_path}"
        echo "********************************"
        # rm -rf "${negative_path}"
        
        continue
    fi

    # Write the extracted information to the main output file with space delimiters
    echo "Writing to main output file: ${output_file}"
    echo "${species} ${ID1} ${ID2} ${fold_id} ${filtered_peaks_path} ${bam_path} ${negative_file}" >> "$output_file"

    # Check if the fold_id is fold_0 and write to the fold_0 file
    if [[ "${fold_id}" == "fold_0" ]]; then
        echo "Writing to fold_0 output file: ${fold0_output_file}"
        echo "${species} ${ID1} ${ID2} ${fold_id} ${filtered_peaks_path} ${bam_path} ${negative_file}" >> "$fold0_output_file"
    fi

    echo "-----------------------------"
    echo "-----------------------------"
    echo "-----------------------------"
done

# Final debug messages after completion
echo "Main output file has been generated at: ${output_file}"
echo "Fold 0 output file has been generated at: ${fold0_output_file}"
echo "Script execution complete."
