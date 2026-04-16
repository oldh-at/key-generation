# key-generation
Generate 1GB of blobs of random noise for keys using OneRNG.

## Overview

This script reads entropy from a OneRNG 3.0 device and generates 1GB of individual 32-byte files containing true hardware random data, saving them to a removable USB drive.

## Requirements

- Raspberry Pi 5 (or any Linux system with USB)
- Fresh install of Raspberry Pi OS (Raspbian)
- OneRNG 3.0 hardware RNG
- USB storage device with at least 1GB free space

## Quick Start

```bash
wget https://raw.githubusercontent.com/oldh-at/key-generation/refs/heads/main/onerng_generate.sh
chmod +x onerng_generate.sh
sudo ./onerng_generate.sh
```

## Detailed Setup

### 1. Prepare Your Raspberry Pi

Update your system:

```bash
sudo apt update && sudo apt upgrade -y
```

Install dependencies:

```bash
sudo apt install rng-tools wget -y
```

Optional: Install the official OneRNG software package for additional verification tools:

```bash
wget https://github.com/OneRNG/onerng.github.io/raw/master/sw/onerng_3.7-1_all.deb
sudo dpkg -i onerng_3.7-1_all.deb
```

### 2. Connect Your OneRNG

Plug the OneRNG into a USB port on your Pi. Verify it's detected:

```bash
lsusb | grep -i "1d50:60c6"
```

You should see:

```
Bus XXX Device XXX: ID 1d50:60c6 OpenMoko, Inc. OneRNG entropy device
```

Check the device node exists:

```bash
ls -la /dev/ttyACM*
```

### 3. Mount Your USB Drive

Insert your USB storage device and identify it:

```bash
lsblk
```

Mount the drive:

```bash
sudo mkdir -p /mnt/usb
sudo mount /dev/sda1 /mnt/usb
```

> **Note:** Replace `/dev/sda1` with your actual device. Use `lsblk` to identify the correct partition.

### 4. Run the Script

Download and execute:

```bash
wget https://raw.githubusercontent.com/oldh-at/key-generation/refs/heads/main/onerng_generate.sh
chmod +x onerng_generate.sh
sudo ./onerng_generate.sh
```

Or specify the output directory directly:

```bash
sudo ./onerng_generate.sh /mnt/usb
```

### 5. Generation Process

The script will:

1. Detect your OneRNG device
2. Find mounted USB drives (or use the directory you specified)
3. Generate 33,554,432 individual 32-byte (256-bit) blob files
4. Create a manifest with SHA256 checksums for each file
5. Display progress with ETA

## Output

After generation, you'll find:

```
/mnt/usb/
└── onerng_random_YYYYMMDD_HHMMSS/
    ├── manifest.txt          # Index with SHA256 for each blob
    ├── blob_00000000.bin     # 32 bytes (256 bits)
    ├── blob_00000001.bin
    ├── blob_00000002.bin
    └── ... (33,554,432 files total)
```

### Manifest Format

The `manifest.txt` file contains metadata and checksums:

```
# OneRNG Random Data Generation
# Generated: Thu Apr 16 12:00:00 UTC 2026
# Device: /dev/ttyACM0
# Blob size: 32 bytes (256 bits)
# Total blobs: 33554432
# Total size: 1073741824 bytes (1GB)
#
# Format: filename sha256sum

blob_00000000.bin a1b2c3d4e5f6...
blob_00000001.bin f6e5d4c3b2a1...
```

## Verification

Verify individual files against the manifest:

```bash
cd /mnt/usb/onerng_random_*/
sha256sum -c manifest.txt
```

## Safely Eject

Always unmount before removing your USB drive:

```bash
sudo umount /mnt/usb
```

## Troubleshooting

### OneRNG not detected

- Try a different USB port
- Check with `dmesg | tail -20` after plugging in
- Ensure no other process is using the device

### Permission denied

- The script must run with `sudo`
- Check device permissions: `ls -la /dev/ttyACM*`

### Read errors during generation

- The OneRNG may need a moment to initialize
- Try unplugging and replugging the device
- Check USB cable quality

## Security Considerations

- Generate data in a secure, offline environment when possible
- Verify checksums after copying to other media
- The OneRNG uses two independent noise sources (avalanche diode and RF) with whitening

## License

MIT License. See [LICENSE](LICENSE) for details.

## Links

- [OneRNG Official Site](https://onerng.info/)
- [OneRNG GitHub](https://github.com/OneRNG)
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/)
