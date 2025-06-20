#!/bin/sh

# Log file location
LOG_FILE="/var/log/usb_mount.log"

# Log function to log messages to both console and log file
log_message() {
    local MESSAGE="$1"
    echo "$MESSAGE" | tee -a "$LOG_FILE"
}

# Get device name (e.g., /dev/sda1)
DEVICE=$1
MOUNT_PARENT_DIR="/mnt/usb"
TARGET_FILE="bee.bin"

log_message "Starting to process device $DEVICE"

# Check if /mnt/usb exists, create it if not
if [ ! -d "$MOUNT_PARENT_DIR" ]; then
    log_message "Directory $MOUNT_PARENT_DIR does not exist. Creating it."
    mkdir -p "$MOUNT_PARENT_DIR"
fi

# Get the device UUID to create a unique mount directory, using lsblk to get UUID
DEVICE_UUID=$(lsblk -o NAME,UUID -n $DEVICE | awk '{print $2}')
log_message "Device UUID: $DEVICE_UUID"

# If UUID retrieval fails, exit the script
if [ -z "$DEVICE_UUID" ]; then
    log_message "Unable to retrieve UUID for $DEVICE. The device may not be ready."
    exit 1
fi

MOUNT_DIR="$MOUNT_PARENT_DIR/$DEVICE_UUID"
log_message "Mount directory: $MOUNT_DIR"

# If the device is already mounted, skip the mount operation
if mount | grep "$MOUNT_DIR" > /dev/null; then
    log_message "$DEVICE already mounted at $MOUNT_DIR"
    exit 0
fi

# Create mount directory with UUID as its name
log_message "Creating mount directory: $MOUNT_DIR"
mkdir -p "$MOUNT_DIR"

# Check if the device can be mounted successfully
if ! mount "$DEVICE" "$MOUNT_DIR"; then
    log_message "Failed to mount $DEVICE to $MOUNT_DIR. Please check the device."
    exit 1
fi

# Check if the bee.bin file exists
if [ -f "$MOUNT_DIR/$TARGET_FILE" ]; then
    log_message "Found $TARGET_FILE on $DEVICE. Copying to /tmp..."
    
    # Copy bee.bin to /tmp
    cp "$MOUNT_DIR/$TARGET_FILE" /tmp/
    
    # Change to /tmp directory
    cd /tmp
    
    # Remove existing update.tar.gz if it exists
    [ -f "update.tar.gz" ] && rm update.tar.gz
    
    # Execute bee-extra command
    log_message "Extracting update.tar.gz from bee.bin..."
    bee-extra -e bee.bin update.tar.gz
    
    # Clean up bee directory if it exists
    [ -d "bee" ] && rm -rf bee
    
    # Extract the archive
    log_message "Extracting update.tar.gz..."
    tar -zxvf update.tar.gz
    
    # Execute run.sh if it exists
    if [ -f "bee/run.sh" ]; then
        log_message "Executing bee/run.sh..."
        bash bee/run.sh
    else
        log_message "Error: bee/run.sh not found after extraction."
    fi
else
    log_message "$MOUNT_DIR/$TARGET_FILE not found on $DEVICE."
fi

log_message "Process completed for $DEVICE"
