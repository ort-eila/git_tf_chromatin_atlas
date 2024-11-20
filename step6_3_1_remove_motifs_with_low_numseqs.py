#!/usr/bin/env python

import logging
import h5py
import os
import shutil

# Configure logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

def copy_logo_images(group_type, pattern_name, valid_image_dir, invalid_image_dir, is_valid, base_logo_dir):
    """
    Copies logo images from the source to the destination based on validity.

    Parameters:
        group_type (str): The type of group (e.g., 'pos_patterns' or 'neg_patterns').
        pattern_name (str): The name of the pattern.
        valid_image_dir (str): Directory for valid images.
        invalid_image_dir (str): Directory for invalid images.
        is_valid (bool): Indicates whether the pattern is valid.
        base_logo_dir (str): Base directory where logo images are located.
    """
    logging.debug(f"Starting to copy logo images for pattern {pattern_name}, is_valid={is_valid}")

    # Construct the logo file paths
    forward_logo_path = os.path.join(base_logo_dir, f"{group_type}.{pattern_name}.cwm.fwd.png")
    reverse_logo_path = os.path.join(base_logo_dir, f"{group_type}.{pattern_name}.cwm.rev.png")
    logging.debug(f"Forward logo path: {forward_logo_path}")
    logging.debug(f"Reverse logo path: {reverse_logo_path}")
    
    # Determine target directory based on validity
    target_dir = valid_image_dir if is_valid else invalid_image_dir
    logging.debug(f"Target directory for logos: {target_dir}")
    
    # Attempt to copy each logo if it exists
    for logo_path in [forward_logo_path, reverse_logo_path]:
        if os.path.exists(logo_path):
            os.makedirs(target_dir, exist_ok=True)  # Ensure target directory exists
            shutil.copy(logo_path, target_dir)
            logging.info(f"Copied logo file: {logo_path} to {target_dir}")
        else:
            logging.warning(f"Logo file not found and skipped: {logo_path}")

def filter_and_copy_patterns(input_file_path, output_dir, group_type, base_logo_dir, threshold=100):
    """
    Filters and copies patterns from the input HDF5 file to valid and invalid output files based on a metric threshold.

    Parameters:
        input_file_path (str): Path to the input HDF5 file.
        output_dir (str): Directory to store output HDF5 files and images.
        group_type (str): Type of group to process (e.g., 'neg_patterns' or 'pos_patterns').
        base_logo_dir (str): Base directory where logo images are located.
        threshold (float): Threshold value for filtering patterns.
    """
    logging.debug(f"Starting filter_and_copy_patterns for group: {group_type}, threshold: {threshold}")
    logging.debug(f"Input file path: {input_file_path}")
    logging.debug(f"Output directory: {output_dir}")
    logging.debug(f"Base logo directory: {base_logo_dir}")

    # Set up paths for valid and invalid outputs
    valid_output_file_path = os.path.join(output_dir, f"valid_{group_type}.h5")
    invalid_output_file_path = os.path.join(output_dir, f"invalid_{group_type}.h5")
    valid_image_dir = os.path.join(output_dir, 'valid_images')
    invalid_image_dir = os.path.join(output_dir, 'invalid_images')
    
    logging.debug(f"Valid output file path: {valid_output_file_path}")
    logging.debug(f"Invalid output file path: {invalid_output_file_path}")
    logging.debug(f"Valid image directory: {valid_image_dir}")
    logging.debug(f"Invalid image directory: {invalid_image_dir}")

    # Create output directories if they do not exist
    os.makedirs(valid_image_dir, exist_ok=True)
    os.makedirs(invalid_image_dir, exist_ok=True)

    try:
        with h5py.File(input_file_path, 'r') as h5_file:
            with h5py.File(valid_output_file_path, 'w') as valid_file, \
                 h5py.File(invalid_output_file_path, 'w') as invalid_file:

                # Access the specified group (e.g., 'neg_patterns' or 'pos_patterns')
                patterns_group = h5_file[group_type]
                logging.debug(f"Patterns group retrieved successfully: {group_type}")
                
                for pattern_name in patterns_group:
                    logging.debug(f"Processing pattern: {pattern_name}")
                    # Retrieve the number of seqlets for the current pattern
                    seqlets_group = patterns_group[f'{pattern_name}/seqlets']
                    n_seqlets_value = seqlets_group['n_seqlets'][()]  # Access the n_seqlets dataset
                    logging.debug(f"n_seqlets for pattern {pattern_name}: {n_seqlets_value}")
                    is_valid = n_seqlets_value >= threshold
                    
                    logging.info(f"Pattern {pattern_name} with n_seqlets {n_seqlets_value} {'passed' if is_valid else 'did not pass'} the threshold of {threshold}")

                    # Decide which file (valid/invalid) to copy data into and copy logo images
                    if is_valid:
                        valid_file.copy(patterns_group[pattern_name], pattern_name)
                        logging.debug(f"Copied pattern {pattern_name} to valid output")
                    else:
                        invalid_file.copy(patterns_group[pattern_name], pattern_name)
                        logging.debug(f"Copied pattern {pattern_name} to invalid output")

                    # Copy logo images based on the pattern validity
                    copy_logo_images(group_type, pattern_name, valid_image_dir, invalid_image_dir, is_valid, base_logo_dir)

    except FileNotFoundError as e:
        logging.error(f"File not found: {e}")
    except KeyError as e:
        logging.error(f"Key error: {e}. Please check if the group type and metric name are valid.")
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")

    logging.info("Completed processing all patterns and consolidated into valid/invalid HDF5 files.")
