import h5py
import logging
import os
import shutil
import glob
import numpy as np

# Set up logging
logging.basicConfig(level=logging.DEBUG, 
                    format="%(asctime)s - %(levelname)s - %(message)s")

# Predefined TN5 isoforms. Taken from chrombpnet output
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
        return False, 0, 0  

    best_similarity = 0
    best_start = 0

    # Slide seqlet across isoform
    for start in range(len(isoform) - len(seqlet) + 1):
        aligned_isoform = isoform[start:start + len(seqlet)]
        similarity_score = sum(1 for a, b in zip(seqlet, aligned_isoform) if a == b) / len(seqlet) * 100

        if similarity_score > best_similarity:
            best_similarity = similarity_score
            best_start = start

    return best_similarity >= threshold, best_similarity, best_start  # first return value is is_invalid

def run_blast_with_isoforms(seqlet, threshold):
    for isoform in TN5_ISOFORMS:
        is_invalid, similarity_score, best_start = run_blast_with_shift(seqlet, isoform, threshold)
        
        if is_invalid:  # The motif is invalid (similarity to TN5 is high)
            return True
    return False

def decode_seqlet(one_hot_seqlet):
    nucleotide_map = ['A', 'C', 'G', 'T']
    
    if not isinstance(one_hot_seqlet, np.ndarray):
        logging.error(f"Expected one-hot encoded sequence (numpy.ndarray), got {type(one_hot_seqlet)}")
        return ""
    
    try:
        return ''.join(nucleotide_map[np.argmax(base)] for base in one_hot_seqlet)
    except Exception as e:
        logging.error(f"Error decoding seqlet: {e}")
        return ""

def copy_logo_images(group_type, pattern_name, valid_dir, invalid_dir, is_invalid, base_logo_dir):
    # Define the source logo paths for both forward and reverse logos
    fwd_logo_pattern = os.path.join(base_logo_dir, f"{group_type}.{pattern_name}.cwm.fwd.png")
    rev_logo_pattern = os.path.join(base_logo_dir, f"{group_type}.{pattern_name}.cwm.rev.png")
    
    logging.info(f"Starting to copy logo images for group '{group_type}' with pattern '{pattern_name}'.")

    # Choose the target directory based on whether the motif is valid or invalid
    target_dir = invalid_dir if is_invalid else valid_dir
    logging.info(f"Target directory determined: {target_dir}.")

    # Ensure that the source logo directory exists
    if not os.path.isdir(base_logo_dir):
        error_message = f"Source logo directory {base_logo_dir} does not exist."
        logging.error(error_message)
        raise FileNotFoundError(error_message)
    
    logging.info(f"Source directory {base_logo_dir} exists. Proceeding to check and copy logos.")

    # Create the target directory if it doesn't exist
    os.makedirs(target_dir, exist_ok=True)
    logging.info(f"Ensured target directory {target_dir} exists.")

    # Copy the logos (forward and reverse) to the respective target directory
    for logo_pattern in [fwd_logo_pattern, rev_logo_pattern]:
        logging.info(f"Checking if logo file exists: {logo_pattern}.")
        
        if os.path.isfile(logo_pattern):
            target_logo_path = os.path.join(target_dir, os.path.basename(logo_pattern))
            if os.path.exists(target_logo_path):
                logging.info(f"Removing existing file {target_logo_path} before copying.")
                os.remove(target_logo_path)  # Ensure the file is deleted before copying
            shutil.copy(logo_pattern, target_logo_path)
            logging.info(f"Logo file copied successfully: {logo_pattern} -> {target_logo_path}.")
        else:
            logging.warning(f"Logo file {logo_pattern} not found.")
    
    logging.info("Finished copying logo images.")


# def copy_logo_images(group_type, pattern_name, valid_dir, invalid_dir, is_invalid, base_logo_dir):
#     # Define the source logo paths for both forward and reverse logos
#     fwd_logo_pattern = os.path.join(base_logo_dir, f"{group_type}.{pattern_name}.cwm.fwd.png")
#     rev_logo_pattern = os.path.join(base_logo_dir, f"{group_type}.{pattern_name}.cwm.rev.png")

#     # Choose the target directory based on whether the motif is valid or invalid
#     target_dir = invalid_dir if is_invalid else valid_dir

#     # Ensure that the source logo directory exists
#     if not os.path.isdir(base_logo_dir):
#         raise FileNotFoundError(f"Source logo directory {base_logo_dir} does not exist.")

#     # Create the target directory if it doesn't exist
#     os.makedirs(target_dir, exist_ok=True)

#     # Copy the logos (forward and reverse) to the respective target directory
#     for logo_pattern in [fwd_logo_pattern, rev_logo_pattern]:
#         if os.path.isfile(logo_pattern):
#             target_logo_path = os.path.join(target_dir, os.path.basename(logo_pattern))
#             if os.path.exists(target_logo_path):
#                 logging.info(f"Removing existing file {target_logo_path} before copying.")
#                 os.remove(target_logo_path)  # Ensure the file is deleted before copying
#             shutil.copy(logo_pattern, target_logo_path)
#         else:
#             logging.warning(f"Logo file {logo_pattern} not found.")

def delete_existing_files_and_folders(valid_image_dir, invalid_image_dir):
    # Delete the logo image directories and their contents
    if os.path.exists(valid_image_dir):
        logging.info(f"Deleting existing valid image directory {valid_image_dir}.")
        shutil.rmtree(valid_image_dir)

    if os.path.exists(invalid_image_dir):
        logging.info(f"Deleting existing invalid image directory {invalid_image_dir}.")
        shutil.rmtree(invalid_image_dir)

def filter_and_copy_patterns(input_file_path, output_dir, group_type, base_logo_dir, threshold):
    valid_image_dir = os.path.join(output_dir, f"{group_type}_valid_logos")
    invalid_image_dir = os.path.join(output_dir, f"{group_type}_invalid_logos")

    # Delete all existing files and directories before starting the process
    delete_existing_files_and_folders(valid_image_dir, invalid_image_dir)

    # Create the directories if they do not exist
    os.makedirs(valid_image_dir, exist_ok=True)
    os.makedirs(invalid_image_dir, exist_ok=True)

    try:
        with h5py.File(input_file_path, 'r') as h5_file:
            if group_type not in h5_file:
                raise KeyError(f"Group '{group_type}' not found in HDF5 file.")

            patterns_group = h5_file[group_type]
            
            for pattern_name in patterns_group:
                try:
                    pattern_group = patterns_group[pattern_name]
                    logging.debug(f"Processing pattern: {group_type}/{pattern_name}")

                    # Check if the pattern has seqlets
                    seqlets_group = pattern_group.get('seqlets')
                    if seqlets_group is None:
                        logging.warning(f"Seqlets not found for pattern {pattern_name}. Skipping.")
                        continue

                    seqlet_one_hot = seqlets_group['sequence'][()]

                    # Decode the seqlet (assuming only one seqlet is processed at a time)
                    seqlet = decode_seqlet(seqlet_one_hot[0])  # Decoding the first seqlet
                    logging.debug(f"Decoded seqlet: {seqlet}")

                    # Run BLAST against TN5 isoforms
                    is_invalid = run_blast_with_isoforms(seqlet, threshold)

                    # Copy logos for the current pattern
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
