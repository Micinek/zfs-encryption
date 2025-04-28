#!/bin/bash
#
# Description: Creates an encrypted ZFS dataset.
# Author: Jan Kocourek
# Date: 2024-08-29
#
# Usage: ./create_encrypted_zfs.sh
#
# Prerequisites:
#   - Root privileges
#   - ZFS installed and configured
#
# Key Storage: /etc/zfs/keys
#
# WARNING: If the encryption key is lost, the data in the
#          encrypted dataset will be unrecoverable.  It is
#          CRITICAL to back up the key securely.
#

print_logo() {
cat << "EOF"
______________________________ ________      _____________________    _______________________________ ___________ _______  ______________.___._______________________________.___________    _______   
\____    /\_   _____/   _____/ \______ \    /  _  \__    ___/  _  \  /   _____/\_   _____/\__    ___/ \_   _____/ \      \ \_   ___ \__  |   |\______   \______   \__    ___/|   \_____  \   \      \  
  /     /  |    __) \_____  \   |    |  \  /  /_\  \|    | /  /_\  \ \_____  \  |    __)_   |    |     |    __)_  /   |   \/    \  \//   |   | |       _/|     ___/ |    |   |   |/   |   \  /   |   \ 
 /     /_  |     \  /        \  |    `   \/    |    \    |/    |    \/        \ |        \  |    |     |        \/    |    \     \___\____   | |    |   \|    |     |    |   |   /    |    \/    |    \
/_______ \ \___  / /_______  / /_______  /\____|__  /____|\____|__  /_______  //_______  /  |____|    /_______  /\____|__  /\______  / ______| |____|_  /|____|     |____|   |___\_______  /\____|__  /
        \/     \/          \/          \/         \/              \/        \/         \/                     \/         \/        \/\/               \/                                 \/         \/ 
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

EOF
}

if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to display available ZFS pools
list_zfs_pools() {
    zpool list -H -o name | awk '$0 !~ /^$/'
}

# Function to validate dataset name
validate_dataset_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Invalid dataset name. Please use alphanumeric characters, dots, underscores, or hyphens."
        return 1
    fi
    return 0
}

clear && print_logo
# Main script execution
echo "Available ZFS Pools:"
list_zfs_pools

read -p "Select a pool: " selected_pool
if ! list_zfs_pools | grep -q "^$selected_pool\$"; then
    echo "Selected pool does not exist."
    exit 1
fi

clear && print_logo
read -p "Enter name for new encrypted dataset: " dataset_name
validate_dataset_name "$dataset_name" || exit 1

clear && print_logo
read -p "Are you sure you want to create the dataset '$dataset_name' on pool '$selected_pool'? (y/n): " confirmation
if [[ "$confirmation" != "y" ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Create encryption key file with printable characters (Base64)
key_file="/etc/zfs/keys/zfs-$dataset_name.key"

# Ensure the key storage directory exists
key_dir=$(dirname "$key_file")
if [ ! -d "$key_dir" ]; then
    mkdir -p "$key_dir"
    chown root:root "$key_dir"
    chmod 750 "$key_dir"
fi

# Generate a 32-character Base64-encoded key and store it
base64 /dev/urandom | head -c 32 > "$key_file" || {
    echo "Failed to create encryption key file."
    exit 1
}

# Set permissions for security
chmod 600 "$key_file"

# Create encrypted ZFS dataset
zfs create -o encryption=aes-256-gcm \
           -o keyformat=raw \
           -o keylocation=file://"$key_file" \
           "${selected_pool}/${dataset_name}" || {
    zfs_error=$(zfs create ...) # Capture the error
    echo "Failed to create encrypted dataset: $zfs_error" >&2 # send to stderr
    exit 1
}

echo "Encrypted dataset '${selected_pool}/${dataset_name}' created successfully."

# Log the action
log_entry="[$(date +'%Y-%m-%d %H:%M:%S')] Created encrypted ZFS dataset '${selected_pool}/${dataset_name}' with key stored at '$key_file'."
echo "$log_entry" | tee -a /var/log/zfs_encryption.log || {
    echo "Failed to log the action."
    exit 1
}

echo "WARNING: It is CRUCIAL to back up the encryption key ( $(readlink -f "$key_file") ) to a safe location, such as a password-protected USB drive or a secure password manager.  Data loss is PERMANENT if the key is lost!"

exit 0