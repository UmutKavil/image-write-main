# image-write-main
image write script
Description: Disk Writing Tool
This bash script is a comprehensive utility for writing disk image files to physical storage devices. Here are its key features:

Disk Selection: Prompts user for target disk name and verifies its existence.

Image File: Looks for img.img by default, asks for custom path if not found.

Disk Check: Verifies if disk is mounted and unmounts if necessary.

Formatting: Offers disk formatting options (FAT32, ExFAT, HFS+, APFS, EXT4, NTFS).

Health Check: Optional disk health verification (using badblocks or diskutil).

Writing Modes:

Normal Write: Faster basic dd command

Safe Write: Cache flushing and synchronized writing for data integrity

Multi-Platform Support: Works on both Linux and macOS systems.

The script provides user feedback at each step and exits with descriptive messages in case of errors.
