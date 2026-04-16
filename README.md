# key-generation
Generate 1GB of blobs of random noise for keys using OneRNG.

## Overview

This script reads entropy from a OneRNG 3.0 device and generates 33,554,432 individual 32-byte files containing true hardware random data, saving them to a removable USB drive.

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

Optional: Install the official OneRNG software package:

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

Replace `/dev/sda1` with your actual device.

### 4. Run the Script

```bash
wget https://raw.githubusercontent.com/oldh-at/key-generation/refs/heads/main/onerng_generate.sh
chmod +x onerng_generate.sh
sudo ./onerng_generate.sh
```

Or specify the output directory directly:

```bash
sudo ./onerng_generate.sh /mnt/usb
```

## Output

```
/mnt/usb/
└── onerng_random_YYYYMMDD_HHMMSS/
    ├── blob_00000000.bin     # 32 bytes (256 bits)
    ├── blob_00000001.bin
    ├── blob_00000002.bin
    └── ... (33,554,432 files total)
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

## License

MIT License. See [LICENSE](LICENSE) for details.

## Links

- [OneRNG Official Site](https://onerng.info/)
- [OneRNG GitHub](https://github.com/OneRNG)
