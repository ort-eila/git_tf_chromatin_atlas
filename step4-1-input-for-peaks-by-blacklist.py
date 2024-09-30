#!/usr/bin/env python3
"""
step4-1-input-for-peaks-by-blacklist.py

This script extracts peak file paths from a specified directory structure
and associates them with species information based on an input mapping file.

Usage:
    python step4-1-input-for-peaks-by-blacklist.py

Dependencies:
    Requires Python 3.x
"""


import os

# Define base path and input file
BASE_PATH = os.path.join(os.getenv('GROUP_SCRATCH'), os.getenv('USER'), 'encode_pseudobulks', 'encode_pseudobulks_data', 'peaks')
INPUT_FILE = './steps_inputs/encids_matched_to_species.txt'
OUTPUT_FILE = './steps_inputs/step4/peaks_with_species.txt'

# Create or clear the output file
with open(OUTPUT_FILE, 'w') as output_file:
    pass

# Check if the input file exists
if not os.path.isfile(INPUT_FILE):
    print(f"Error: Input file '{INPUT_FILE}' not found!")
    exit(1)

# Read species information into a dictionary
species_map = {}
with open(INPUT_FILE, 'r') as infile:
    for line in infile:
        encsr_id, species = line.strip().split()
        # print(f"Loaded: '{encsr_id}' -> '{species}'")  # Debug line
        species_map[encsr_id] = species

# Debug: Print the species map
# print("Species map contents:")
# for encsr_id, species in species_map.items():
#     print(f"'{encsr_id}' -> '{species}'")

# Loop through the first level directories (ENCSR IDs)
for encsr_dir in os.listdir(BASE_PATH):
    encsr_path = os.path.join(BASE_PATH, encsr_dir)
    if os.path.isdir(encsr_path):  # Check if it's a directory
        # print(f"Processing ENCSR ID: '{encsr_dir}'")  # Debug line

        # Check if the ID is in the species map
        if encsr_dir in species_map:
            species = species_map[encsr_dir]  # Retrieve species for the ENCSR ID
            # print(f"Match found: '{encsr_dir}' -> '{species}'")  # Debug line

            # Get the subdirectory that contains the .bed.gz file
            for sub_dir in os.listdir(encsr_path):
                sub_dir_path = os.path.join(encsr_path, sub_dir)
                if os.path.isdir(sub_dir_path):  # Check if it's a subdirectory
                    # print(f"Checking subdirectory: '{sub_dir_path}'")  # Debug line

                    # Get the .bed.gz file in the subdirectory (assuming there's only one)
                    peak_files = [f for f in os.listdir(sub_dir_path) if f.endswith('.bed.gz')]
                    if peak_files:  # Check if the file exists
                        peak_file = os.path.join(sub_dir_path, peak_files[0])  # Get the full path of the file
                        # print(f"Found peak file: '{peak_file}'")  # Debug line

                        # Output the peak file path with species information
                        with open(OUTPUT_FILE, 'a') as output_file:
                            output_file.write(f"{peak_file} {species}\n")  # Write to output file
                        print(f"Added to output: '{peak_file}' '{species}'")  # Debug line
                    else:
                        print(f"No .bed.gz file found in '{sub_dir_path}'")  # Debug line
        else:
            print(f"No species match for ENCSR ID: '{encsr_dir}'")  # Debug line

print(f"Peak extraction completed. Results saved to '{OUTPUT_FILE}'.")
