#!/usr/bin/env python

import logging
import h5py
import os
import shutil

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def copy_motif_images(pattern_name, valid_image_dir, invalid_image_dir, is_valid, base_logo_dir):
    """
    Copies motif images based on their validity.

    Parameters:
        pattern_name (str): The name of the motif pattern.
        valid_image_dir (str): Directory for valid motif images.
        invalid_image_dir (str): Directory for invalid motif images.
        is_valid (bool): Indicates whether the motif is valid.
        base_logo_dir (str): Base directory for motif images.
    """
    forward_logo_path = os.path.join(base_logo_dir, f"{pattern_name}.cwm.fwd.png")
    reverse_logo_path = os.path.join(base_logo_dir, f"{pattern_name}.cwm.rev.png")
    
    target_dir = valid_image_dir if is_valid else invalid_image_dir
    
    for logo_path in [forward_logo_path, reverse_logo_path]:
        if os.path.exists(logo_path):
            os.makedirs(target_dir, exist_ok=True)
            shutil.copy(logo_path, target_dir)
            logging.info(f"Copied logo file: {logo_path} to {target_dir}")
        else:
            logging.warning(f"Logo file not found and skipped: {logo_path}")

def filter_and_copy_motifs(input_file_path, output_dir, threshold=0.0001, base_logo_dir=""):
    """
    Filters and copies motifs from an HDF5 file based on match q-value thresholds.

    Parameters:
        input_file_path (str): Path to the input HDF5 file.
        output_dir (str): Directory to store valid and invalid motif outputs.
        threshold (float): q-value threshold for valid motifs.
        base_logo_dir (str): Directory containing motif images.
    """
    valid_output_path = os.path.join(output_dir, "valid_motifs.h5")
    invalid_output_path = os.path.join(output_dir, "invalid_motifs.h5")
    valid_image_dir = os.path.join(output_dir, 'valid_images')
    invalid_image_dir = os.path.join(output_dir, 'invalid_images')
    
    os.makedirs(valid_image_dir, exist_ok=True)
    os.makedirs(invalid_image_dir, exist_ok=True)
    
    try:
        with h5py.File(input_file_path, 'r') as h5_file:
            with h5py.File(valid_output_path, 'w') as valid_file, \
                 h5py.File(invalid_output_path, 'w') as invalid_file:
                
                for pattern_name in h5_file:
                    # Access match q-values for the current motif
                    qval0 = h5_file[f'{pattern_name}/qval0'][()]
                    qval1 = h5_file[f'{pattern_name}/qval1'][()]
                    qval2 = h5_file[f'{pattern_name}/qval2'][()]
                    
                    # Determine validity based on q-value threshold
                    is_valid = (qval0 < threshold or qval1 < threshold or qval2 < threshold)
                    
                    logging.info(f"Motif {pattern_name} with qval0 {qval0}, qval1 {qval1}, qval2 {qval2} {'passed' if is_valid else 'did not pass'} the threshold of {threshold}")

                    # Copy motifs to the appropriate file based on validity
                    if is_valid:
                        valid_file.copy(h5_file[pattern_name], pattern_name)
                    else:
                        invalid_file.copy(h5_file[pattern_name], pattern_name)
                    
                    # Copy motif images
                    copy_motif_images(pattern_name, valid_image_dir, invalid_image_dir, is_valid, base_logo_dir)
    
    except FileNotFoundError as e:
        logging.error(f"File not found: {e}")
    except KeyError as e:
        logging.error(f"Key error: {e}. Please check motif attributes.")
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")

    logging.info("Motif filtering and copying completed.")
