#!/bin/bash

set -e

# ──────[ Colors for Output ]──────
RED="\e[91m"
GREEN="\e[92m"
YELLOW="\e[93m"
BLUE="\e[94m"
WHITE="\e[97m"
ENDCOLOR="\e[0m"

INFO_MSG="${WHITE}[INFO]:    ${ENDCOLOR}"
SUCCESS_MSG="${GREEN}[SUCCESS]: ${ENDCOLOR}"
WARNING_MSG="${YELLOW}[WARNING]: ${ENDCOLOR}"
ERROR_MSG="${RED}[ERROR]:   ${ENDCOLOR}"

# ──────[ Variables ]──────
MOUNT_DIR="/tmp/mnt_qcow2"
OUTPUT_DIR="/tmp/qcow2_kernel_initrd"
REQUIRED_CMDS=("qemu-nbd" "mount" "umount" "lsblk" "readlink" "partprobe" "blockdev")

# ──────[ Help Message ]──────
show_help() {
  echo -e "${INFO_MSG}Usage: $0 <image.qcow2>"
  echo ""
  echo "This script extracts the Linux kernel (vmlinuz) and initrd (initrd.img)"
  echo "from a QCOW2 disk image and copies them to: ${OUTPUT_DIR}"
  echo ""
  echo "It supports images with partition tables as well as images without partitions."
  echo ""
  echo "Options:"
  echo "  -h, --help        Show this help message"
  echo ""
  echo "Dependencies:"
  echo "  sudo apt install qemu-utils"
}

# ──────[ Check for Required Commands ]──────
check_dependencies() {
  for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "${cmd}" > /dev/null 2>&1; then
      echo -e "${ERROR_MSG}Command '${cmd}' is required but not found."
      echo -e "${INFO_MSG}You can install it on Debian/Ubuntu with:"
      echo -e "           sudo apt update && sudo apt install qemu-utils"
      exit 1
    fi
  done
}

# ──────[ Disconnect nbd if connected ]──────
disconnect_nbd() {
  if lsblk -ln | grep -q "^nbd0"; then
    echo -e "${INFO_MSG}Checking if /dev/nbd0 is already mounted or connected..."
    # Check for mounted partitions on nbd0
    MOUNTED_PARTS=$(lsblk -ln -o MOUNTPOINT /dev/nbd0* | grep -v '^$' || true)
    if [[ -n "${MOUNTED_PARTS}" ]]; then
      echo -e "${ERROR_MSG}Some partitions of /dev/nbd0 are still mounted. Please unmount them before running this script."
      exit 1
    fi
    echo -e "${INFO_MSG}Disconnecting /dev/nbd0..."
    sudo qemu-nbd -d /dev/nbd0 || true
  else
    echo -e "${INFO_MSG}/dev/nbd0 not connected."
  fi
}

# ──────[ Try to find kernel and initrd in a mounted directory ]──────
find_kernel_initrd() {
  local search_path="$1"
  # Search for vmlinuz* and initrd* files under /boot inside the mounted partition
  # Prefer /boot/vmlinuz and /boot/initrd.img, fallback to /vmlinuz and /initrd.img
  # We also accept symbolic links, copy the pointed files

  local kernel_file=""
  local initrd_file=""

  # Look under /boot first
  for k in vmlinuz vmlinuz-*; do
    if [[ -e "${search_path}/boot/${k}" ]]; then
      kernel_file="${search_path}/boot/${k}"
      break
    fi
  done

  for i in initrd.img initrd.img-* initramfs.img initramfs.img-*; do
    if [[ -e "${search_path}/boot/${i}" ]]; then
      initrd_file="${search_path}/boot/${i}"
      break
    fi
  done

  # If not found under /boot, try root
  if [[ -z "${kernel_file}" ]]; then
    for k in vmlinuz vmlinuz-*; do
      if [[ -e "${search_path}/${k}" ]]; then
        kernel_file="${search_path}/${k}"
        break
      fi
    done
  fi

  if [[ -z "${initrd_file}" ]]; then
    for i in initrd.img initrd.img-* initramfs.img initramfs.img-*; do
      if [[ -e "${search_path}/${i}" ]]; then
        initrd_file="${search_path}/${i}"
        break
      fi
    done
  fi

  if [[ -n "${kernel_file}" && -n "${initrd_file}" ]]; then
    echo "${kernel_file}|${initrd_file}"
  else
    echo ""
  fi
}

# ──────[ Main Script Start ]──────
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

if [[ $# -ne 1 ]]; then
  echo -e "${ERROR_MSG}No QCOW2 image provided."
  show_help
  exit 1
fi

QCOW2_IMAGE="${1}"

if [[ ! -f "${QCOW2_IMAGE}" ]]; then
  echo -e "${ERROR_MSG}File '${QCOW2_IMAGE}' not found."
  exit 1
fi

check_dependencies

disconnect_nbd

echo -e "${INFO_MSG}Loading nbd kernel module if not already loaded..."
if ! lsmod | grep -q "^nbd"; then
  sudo modprobe nbd max_part=16
else
  echo -e "${INFO_MSG}nbd module already loaded."
fi

echo -e "${INFO_MSG}Connecting image with qemu-nbd..."
sudo qemu-nbd -c /dev/nbd0 "${QCOW2_IMAGE}"

# Wait for devices to appear
echo -e "${INFO_MSG}Waiting for partition devices to appear..."
sleep 2
sudo partprobe /dev/nbd0 || true

PARTITIONS=()
while read -r part; do
  PARTITIONS+=("/dev/${part}")
done < <(lsblk -ln -o NAME /dev/nbd0 | tail -n +2)

MOUNTED=0
FOUND_KERNEL_INITRD=0

mkdir -p "${MOUNT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Try mounting partitions if any found
if [[ ${#PARTITIONS[@]} -gt 0 ]]; then
  for PART in "${PARTITIONS[@]}"; do
    echo -e "${INFO_MSG}Trying partition ${PART}..."
    sudo mount "${PART}" "${MOUNT_DIR}" || {
      echo -e "${WARNING_MSG}Failed to mount ${PART}, skipping."
      continue
    }

    RESULT=$(find_kernel_initrd "${MOUNT_DIR}")

    if [[ -n "${RESULT}" ]]; then
      FOUND_KERNEL_INITRD=1
      KERNEL_FILE="${RESULT%%|*}"
      INITRD_FILE="${RESULT##*|}"

      # Resolve symlinks and copy actual files
      KERNEL_REALPATH=$(readlink -f "${KERNEL_FILE}")
      INITRD_REALPATH=$(readlink -f "${INITRD_FILE}")

      echo -e "${SUCCESS_MSG}Found kernel and initrd in ${PART}."
      cp "${KERNEL_REALPATH}" "${OUTPUT_DIR}/vmlinuz"
      cp "${INITRD_REALPATH}" "${OUTPUT_DIR}/initrd.img"

      sudo umount "${MOUNT_DIR}"
      break
    fi

    sudo umount "${MOUNT_DIR}"
  done
fi

# If not found in partitions, try mounting /dev/nbd0 directly (no partitions)
if [[ "${FOUND_KERNEL_INITRD}" -eq 0 ]]; then
  echo -e "${INFO_MSG}No partitions with kernel/initrd found, trying to mount /dev/nbd0 directly..."
  sudo mount /dev/nbd0 "${MOUNT_DIR}" || {
    echo -e "${ERROR_MSG}Failed to mount /dev/nbd0 directly."
    sudo qemu-nbd -d /dev/nbd0
    exit 2
  }

  RESULT=$(find_kernel_initrd "${MOUNT_DIR}")

  if [[ -n "${RESULT}" ]]; then
    KERNEL_FILE="${RESULT%%|*}"
    INITRD_FILE="${RESULT##*|}"

    KERNEL_REALPATH=$(readlink -f "${KERNEL_FILE}")
    INITRD_REALPATH=$(readlink -f "${INITRD_FILE}")

    echo -e "${SUCCESS_MSG}Found kernel and initrd in /dev/nbd0 device."
    cp "${KERNEL_REALPATH}" "${OUTPUT_DIR}/vmlinuz"
    cp "${INITRD_REALPATH}" "${OUTPUT_DIR}/initrd.img"

    FOUND_KERNEL_INITRD=1
  else
    echo -e "${ERROR_MSG}Could not locate vmlinuz or initrd.img in the image."
  fi

  sudo umount "${MOUNT_DIR}"
fi

echo -e "${INFO_MSG}Disconnecting /dev/nbd0..."
sudo qemu-nbd -d /dev/nbd0 || true

if [[ "${FOUND_KERNEL_INITRD}" -eq 1 ]]; then
  echo -e "${SUCCESS_MSG}Kernel and initrd copied to: ${OUTPUT_DIR}"
  ls -lh "${OUTPUT_DIR}"
  exit 0
else
  echo -e "${ERROR_MSG}Failed to find kernel and initrd in the image."
  exit 3
fi
