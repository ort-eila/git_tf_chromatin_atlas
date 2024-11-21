#!/usr/bin/env python

import h5py
import logging
import os
import shutil
import glob
import numpy as np

# Set up logging
logging.basicConfig(level=logging.DEBUG, 
                    format="%(asctime)s - %(levelname)s - %(message)s")

# Predefined TN5 isoforms. Taken from chrombpet output
TN5_ISOFORMS = [
    "GCACAGTACAGAGCTG",         # tn5_1
    "GTGCACAGTTCTAGAGTGTGCAG",  # tn5_2
    "CCTCTACACTGTGCAGAA",       # tn5_3
    "GCACAGTTCTAGACTGTGCAG",    # tn5_4
    "CTGCACAGTGTAGAGTTGTGC"     # tn5_5
]

def run_blast_with_shift(seqlet, isoform, threshold):
    if len(seqlet) > len(isoform):
        logging.warning(f"Seqlet is longer than isoform {isoform}, skipping BLAST.")
        return False, 0, 0  # Or another appropriate fallback

    best_similarity = 0
    best_start = 0

    # Slide seqlet across isoform
    for start in range(len(isoform) - len(seqlet) + 1):  # Ensure seqlet fits within isoform
        logging.debug(f"start position is : {start}")
        aligned_isoform = isoform[start:start + len(seqlet)]
        similarity_score = sum(1 for a, b in zip(seqlet, aligned_isoform) if a == b) / len(seqlet) * 100

        if similarity_score > best_similarity:
            best_similarity = similarity_score
            best_start = start

    logging.debug(f"Best similarity score: {best_similarity} at position {best_start} (threshold: {threshold})")

    # Return True if best similarity meets threshold, otherwise False
    return best_similarity >= threshold, best_similarity, best_start

def run_blast_with_isoforms(seqlet, threshold):
    logging.debug(f"Checking seqlet: {seqlet} against all TN5 isoforms.")
    for isoform in TN5_ISOFORMS:
        is_invalid, similarity_score, best_start = run_blast_with_shift(seqlet, isoform, threshold)
        logging.debug(f"Similarity: {similarity_score}% at position {best_start} (threshold: {threshold})")
        
        if is_invalid: #means that the motif is invalid - the similarity to TN5 is high
            logging.info(f"Seqlet matched with TN5 isoform: {isoform} (score: {similarity_score}%, start: {best_start})")
            return True
    logging.debug("Seqlet did not match any TN5 isoform. It is a valid seqlet")
    return False


def decode_seqlet(one_hot_seqlet):
    """
    Decodes a one-hot encoded sequence to a nucleotide string.
    Parameters:
        one_hot_seqlet (numpy.ndarray): One-hot encoded sequence of shape (N, 4).
    Returns:
        str: Decoded nucleotide sequence.
    
    Example:
    one_hot_seqlet = np.array([
    [1, 0, 0, 0],  # A
    [0, 1, 0, 0],  # C
    [0, 0, 1, 0],  # G
    [0, 0, 0, 1]   # T])
    """
    nucleotide_map = ['A', 'C', 'G', 'T']
    
    if not isinstance(one_hot_seqlet, np.ndarray):
        logging.error(f"Expected one-hot encoded sequence (numpy.ndarray), got {type(one_hot_seqlet)}")
        return ""
    
    try:
        decoded_seqlet = ''.join(nucleotide_map[np.argmax(base)] for base in one_hot_seqlet)
        return decoded_seqlet
    except Exception as e:
        logging.error(f"Error decoding seqlet: {e}")
        return ""


def copy_logo_images(group_type, pattern_name, valid_dir, invalid_dir, is_invalid, base_logo_dir):
    logging.debug(f"Starting to process logos for pattern: {pattern_name}, group: {group_type}, is_valid: {is_valid}")

    source_logo_dir = os.path.join(base_logo_dir, group_type + '.' + pattern_name + '.*')
    target_dir = invalid_dir if is_invalid else valid_dir

    logging.debug(f"Source logo directory: {source_logo_dir}")
    logging.debug(f"Target directory: {target_dir}")

    if not os.path.isdir(base_logo_dir):
        error_msg = f"Source logo directory {base_logo_dir} does not exist."
        logging.error(error_msg)
        raise FileNotFoundError(error_msg)

    os.makedirs(target_dir, exist_ok=True)
    logging.debug(f"Ensured that target directory {target_dir} exists.")

    source_files = glob.glob(source_logo_dir)
    if not source_files:
        error_msg = f"No files matched the pattern {source_logo_dir}."
        logging.error(error_msg)
        raise FileNotFoundError(error_msg)

    logging.debug(f"Found {len(source_files)} file(s) to process.")

    for source_path in source_files:
        file_name = os.path.basename(source_path)
        target_path = os.path.join(target_dir, file_name)

        logging.debug(f"Processing file: {source_path}, Target path: {target_path}")
        
        # Check if the file exists in the target directory
        if os.path.isfile(source_path):
            logging.debug(f"Source file {source_path} exists. Checking for conflicts in the target directory.")
            
            if os.path.exists(target_path):  # If the file already exists, raise an error
                logging.error(f"Destination file already exists: Source: {source_path}, Destination: {target_path}")
                raise FileExistsError(f"Destination file already exists: {target_path}")
            else:
                # If no conflict, copy the file to the target directory
                logging.debug(f"Copying file from {source_path} to {target_path}.")
                shutil.copy(source_path, target_path)
                logging.info(f"Copied logo: {file_name} to {'valid' if is_valid else 'invalid'} directory.")
        else:
            logging.warning(f"Source file does not exist: {source_path}")

    logging.debug(f"Completed processing logos for pattern: {pattern_name}, group: {group_type}, is_valid: {is_valid}")


def filter_and_copy_patterns(input_file_path, output_dir, group_type, base_logo_dir, threshold):
    valid_output_file_path = os.path.join(output_dir, f"{group_type}_valid.h5")
    invalid_output_file_path = os.path.join(output_dir, f"{group_type}_invalid.h5")
    valid_image_dir = os.path.join(output_dir, f"{group_type}_valid_logos")
    invalid_image_dir = os.path.join(output_dir, f"{group_type}_invalid_logos")

    logging.info(f"Ensuring output directories exist.")
    os.makedirs(valid_image_dir, exist_ok=True)
    os.makedirs(invalid_image_dir, exist_ok=True)

    logging.info(f"Processing group type: {group_type}")
    try:
        with h5py.File(input_file_path, 'r') as h5_file:
            if group_type not in h5_file:
                raise KeyError(f"Group '{group_type}' not found in HDF5 file.")

            patterns_group = h5_file[group_type]
            logging.info(f"Opened HDF5 file: {input_file_path}")
            
            with h5py.File(valid_output_file_path, 'w') as valid_file, \
                 h5py.File(invalid_output_file_path, 'w') as invalid_file:

                for pattern_name in patterns_group:
                    logging.debug(f"Processing pattern: {pattern_name}")
                    try:
                        seqlets_group = patterns_group[f'{pattern_name}/seqlets']
                        seqlet_one_hot = seqlets_group['sequence'][()]
                        logging.debug(f"Seqlet one-hot encoding shape: {seqlet_one_hot.shape}")
                        
                        for seqlet_data in seqlet_one_hot:
                            seqlet = decode_seqlet(seqlet_data)
                            logging.debug(f"Decoded seqlet: {seqlet}")

                            # Run BLAST against TN5 isoforms
                            is_invalid = run_blast_with_isoforms(seqlet, threshold)

                            # Save results and copy logo images
                            if is_invalid:
                                invalid_file.copy(patterns_group[pattern_name], pattern_name)
                                logging.info(f"Pattern {pattern_name} is invalid and saved.")
                            else:
                                valid_file.copy(patterns_group[pattern_name], pattern_name)
                                logging.info(f"Pattern {pattern_name} is valid and saved.")
                                

                            copy_logo_images(group_type, pattern_name, valid_image_dir, invalid_image_dir, is_invalid, base_logo_dir)

                    except KeyError as e:
                        logging.error(f"Missing key for pattern {pattern_name}: {e}")
                    except Exception as e:
                        logging.error(f"Error processing pattern {pattern_name}: {e}")
                        
    except FileNotFoundError as e:
        logging.error(f"Input file not found: {e}")
    except KeyError as e:
        logging.error(f"Group not found in HDF5 file: {e}")
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
