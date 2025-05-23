#!/usr/bin/env python3
"""
step4-1-input-for-peaks-by-blacklist.py

This script extracts peak file paths from a specified directory structure
and associates them with organism information based on an input mapping file.

Usage:
    python step4-1-input-for-peaks-by-blacklist.py

Dependencies:
    Requires Python 3.x
"""

import os

# Define base path and input file
BASE_PATH = os.path.join(os.getenv('GROUP_SCRATCH'), os.getenv('USER'), 'encode_pseudobulks', 'encode_pseudobulks_data', 'peaks')
INPUT_FILE = './steps_inputs/step4/atac_pseudobulk_new_peaks_files_mapping.txt'
OUTPUT_FILE = './steps_inputs/step4/peaks_with_organism.txt'

# Create or overwrite the output file
with open(OUTPUT_FILE, 'w') as output_file:
    pass

# Check if the input file exists
if not os.path.isfile(INPUT_FILE):
    print(f"Error: Input file '{INPUT_FILE}' not found!")
    exit(1)

# Read organism information into a dictionary
organism_map = {}
with open(INPUT_FILE, 'r') as infile:
    next(infile)  # Skip the header line
    for line in infile:
        fields = line.strip().split(',')
        encsr_id = fields[0].strip('/').split('/')[-1]  # Extract ENCSR ID
        organism = fields[3].replace(" ", "_")  # Replace spaces in the organism name
        organism_map[encsr_id] = organism

# Debug: Print the organism map
print("Organism map contents:")
for encsr_id, organism in organism_map.items():
    print(f"'{encsr_id}' -> '{organism}'")

# Loop through the first level directories (ENCSR IDs)
for encsr_dir in os.listdir(BASE_PATH):
    encsr_path = os.path.join(BASE_PATH, encsr_dir)
    if os.path.isdir(encsr_path):  # Check if it's a directory
        print(f"Processing ENCSR ID: '{encsr_dir}'")  # Debug message for ENCSR ID

        # Check if the ID is in the organism map
        if encsr_dir in organism_map:
            organism = organism_map[encsr_dir]
            print(f"Match found: '{encsr_dir}' -> '{organism}'")  # Debug message for organism

            # Get the subdirectory that contains the .bed.gz file
            for sub_dir in os.listdir(encsr_path):
                sub_dir_path = os.path.join(encsr_path, sub_dir)
                if os.path.isdir(sub_dir_path):  # Check if it's a subdirectory

                    # Get the .bed.gz file in the subdirectory (assuming there's only one)
                    peak_files = [f for f in os.listdir(sub_dir_path) if f.endswith('.bed.gz')]
                    if peak_files:  # Check if the file exists
                        peak_file = os.path.join(sub_dir_path, peak_files[0])  # Get the full path of the file

                        # Output the peak file path with organism information
                        with open(OUTPUT_FILE, 'a') as output_file:
                            output_file.write(f"{peak_file} {organism}\n")  # Write to output file
                        print(f"Added to output: '{peak_file}' '{organism}'")  # Debug message
                    else:
                        print(f"No .bed.gz file found in '{sub_dir_path}'")  # Debug message
        else:
            print(f"No organism match for ENCSR ID: '{encsr_dir}'")  # Debug message

print(f"Peak extraction completed. Results saved to '{OUTPUT_FILE}'.")
