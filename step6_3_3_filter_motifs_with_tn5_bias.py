import h5py
import logging
import os

# Set up logging
logging.basicConfig(level=logging.DEBUG, 
                    format="%(asctime)s - %(levelname)s - %(message)s")

# Predefined TN5 isoforms
TN5_ISOFORMS = [
    "GCACAGTACAGAGCTG",         # tn5_1
    "GTGCACAGTTCTAGAGTGTGCAG",  # tn5_2
    "CCTCTACACTGTGCAGAA",       # tn5_3
    "GCACAGTTCTAGACTGTGCAG",    # tn5_4
    "CTGCACAGTGTAGAGTTGTGC"     # tn5_5
]

def run_blast(seqlet, isoform, threshold):
    logging.debug(f"Running BLAST for seqlet: {seqlet} against isoform: {isoform}")
    similarity_score = sum(1 for a, b in zip(seqlet, isoform) if a == b) / len(isoform) * 100
    logging.debug(f"Similarity score: {similarity_score} (threshold: {threshold})")
    return similarity_score >= threshold

def run_blast_with_shift(seqlet, isoform, threshold):
    best_similarity = 0
    best_start = 0

    # Slide seqlet across isoform
    for start in range(len(isoform) - len(seqlet) + 1):  # Ensure seqlet fits within isoform
        aligned_isoform = isoform[start:start + len(seqlet)]
        similarity_score = sum(1 for a, b in zip(seqlet, aligned_isoform) if a == b) / len(seqlet) * 100

        if similarity_score > best_similarity:
            best_similarity = similarity_score
            best_start = start

    # Debugging information
    logging.debug(f"Best similarity score: {best_similarity} at position {best_start} (threshold: {threshold})")

    # Return True if best similarity meets threshold, otherwise False
    return best_similarity >= threshold, best_similarity, best_start

def run_blast_with_isoforms(seqlet, threshold):
    logging.debug(f"Checking seqlet: {seqlet} against all TN5 isoforms.")
    for isoform in TN5_ISOFORMS:
        is_valid, similarity_score, best_start = run_blast_with_shift(seqlet, isoform, threshold)
        logging.debug(f"Similarity: {similarity_score}% at position {best_start} (threshold: {threshold})")
        
        if is_valid:
            logging.info(f"Seqlet matched with TN5 isoform: {isoform} (score: {similarity_score}%, start: {best_start})")
            return False
    logging.debug("Seqlet did not match any TN5 isoform. it is a valid seqlet")
    return True


def decode_seqlet(one_hot_seqlet):
    """
    Decodes a one-hot encoded sequence to a nucleotide string.
    Parameters:
        one_hot_seqlet (numpy.ndarray): One-hot encoded sequence of shape (N, 4).
    Returns:
        str: Decoded nucleotide sequence.
    """
    import numpy as np
    nucleotide_map = ['A', 'C', 'G', 'T']
    try:
        decoded_seqlet = ''.join(nucleotide_map[np.argmax(base)] for base in one_hot_seqlet)
        return decoded_seqlet
    except Exception as e:
        logging.error(f"Error decoding seqlet: {e}")
        return ""

def copy_logo_images(group_type, pattern_name, valid_dir, invalid_dir, is_valid, base_logo_dir):
    source_logo_dir = os.path.join(base_logo_dir, group_type, pattern_name)
    target_dir = valid_dir if is_valid else invalid_dir
    logging.debug(f"Copying logos from {source_logo_dir} to {target_dir}")
    if os.path.exists(source_logo_dir):
        os.makedirs(target_dir, exist_ok=True)
        for file_name in os.listdir(source_logo_dir):
            source_path = os.path.join(source_logo_dir, file_name)
            target_path = os.path.join(target_dir, file_name)
            os.symlink(source_path, target_path)
        logging.info(f"Copied logos for pattern: {pattern_name} to {'valid' if is_valid else 'invalid'} directory.")
    else:
        logging.warning(f"Source logo directory {source_logo_dir} does not exist. Skipping logo copying.")

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
                        
                        # Extract each seqlet (i.e., a single sequence of length 30)
                        for seqlet_data in seqlet_one_hot:
                            # seqlet_data has shape (30, 4), corresponding to a single 30-base sequence
                            seqlet = decode_seqlet(seqlet_data)  # Decode to string
                            logging.debug(f"Decoded seqlet: {seqlet}")

                            # Run BLAST against TN5 isoforms
                            is_valid = run_blast_with_isoforms(seqlet, threshold)

                            # Save results and copy logo images
                            if is_valid:
                                valid_file.copy(patterns_group[pattern_name], pattern_name)
                                logging.info(f"Pattern {pattern_name} is valid and saved.")
                            else:
                                invalid_file.copy(patterns_group[pattern_name], pattern_name)
                                logging.info(f"Pattern {pattern_name} is invalid and saved.")

                            copy_logo_images(group_type, pattern_name, valid_image_dir, invalid_image_dir, is_valid, base_logo_dir)

                    except KeyError as e:
                        logging.error(f"Missing key for pattern {pattern_name}: {e}")
                    except Exception as e:
                        logging.error(f"Error processing pattern {pattern_name}: {e}")
                        
    except FileNotFoundError as e:
        logging.error(f"Input file not found: {e}")
    except KeyError as e:
        logging.error(f"Group {group_type} error: {e}")
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
