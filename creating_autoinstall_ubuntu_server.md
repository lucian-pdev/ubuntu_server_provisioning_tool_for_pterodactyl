Cloud-init runs in both the ephemeral system during OS install and the first boot.

#cloud-config
# cloud-init directives may optionally be specified here.
# These directives affect the ephemeral system performing the installation.

autoinstall:
    # autoinstall directives must be specified here, not directly at the
    # top level.  These directives are processed by the Ubuntu Installer,
    # and configure the target system to be installed.

    user-data:
        # cloud-init directives may also be optionally be specified here.
        # These directives also affect the target system to be installed,
        # and are processed on first boot.

References for each field in the autoinstall file: https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html

At installation time, the default user should be considered to have root privileges.
Additionally, there is an NOPASSWD entry in the /etc/sudoers.d for the default user, which means that the default installer user can become root at any time with a sudo invocation.

### Storage ###
The OS install will auto-partition it's first recorded drive to it's needs if left with the default "lvm" option.

Adding additional disks post-install:
wipefs -a /dev/sdX
pvcreate /dev/sdX
vgextend vg0 /dev/sdX
lvextend -r -l +100%FREE /dev/vg0/root


### Creating the instalation media ###

1. Xorriso

# extracting ISO contents
$ mkdir iso
$ xorriso -osirrox on -indev ubuntu.iso -extract / iso/

## explanation
[command] xorriso
[options] -osirrox on -indev
[path_to_original_iso] -ubuntu.iso
[option] -extract
[/=root_inside_iso] /
[iso/=dir_to_extract_into] iso/

# adding autoinstall files

mkdir -p iso/autoinstall
cp user-data            #if you use web-based autoinstall provisioning
touch meta-data         #user-data is cloud-config

## Paths:
install_media_root/autoinstall/
├── user-data
└── meta-data

# Make the ISO boot automatically into autoinstall
##Ubuntu Server needs a kernel command-line flag added to GRUB, for that:

1. Edit iso/boot/grub/grub.cfg
2. Find "Install Ubuntu Server"
3. Modify the line to: 

linux   /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/autoinstall/ ---

4. Do the same for iso/boot/grub/loopback.cfg

# Repack the iso with xorriso

xorriso -as mkisofs \
    -r -V "UBUNTU_AUTOINSTALL" \
    -o ubuntu-autoinstall.iso   \
    -J -l -cache-inodes -partition_offset 16 \
    -b boot/grub/i386-pc/eltorito.img  \
    -c boot.catalog \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e EFI/boot/bootx64.efi -no-emul-boot iso

## explanation
[command] xorriso -as mkisofs
    Runs xorriso in mkisofs compatibility mode, allowing it to create ISO images using the same flags as mkisofs/genisoimage. This is the standard method for rebuilding Ubuntu installation media.

[Options]:
    -r  
    Sets file ownership/permissions to sane defaults for ISO9660 (root:root, read-only).
    Ensures reproducible permissions.

    -V "UBUNTU_AUTOINSTALL"  
    Sets the ISO volume label.
    This is what shows up when the disk is mounted.

    -o ubuntu-autoinstall.iso  
    Output filename for the rebuilt ISO.

    -J  
    Enables Joliet extensions (Windows-compatible long filenames).

    -l  
    Allows long filenames (up to 31 chars) in ISO9660.

    -cache-inodes  
    Avoids duplicate inode warnings; improves compatibility.

    -partition_offset 16  
    Ensures proper alignment for hybrid BIOS/UEFI boot.
    Ubuntu’s official ISOs use this offset.

    # BIOS boot section (El Torito) #

    -b boot/grub/i386-pc/eltorito.img  
    Specifies the BIOS boot image (El Torito).
    This file is inside the ISO and contains GRUB for legacy BIOS systems.

    -c boot.catalog
    For ubuntu server, gives the ephemeral system "Subiquity" the 2 necesary boot entries.

    -no-emul-boot  
    Tells BIOS to treat the boot image as a raw disk, not a floppy.

    -boot-load-size 4  
    Loads the first 4 sectors of the boot image (standard for GRUB).

    -boot-info-table  
    Writes metadata into the boot image so GRUB can find the ISO contents.

    # UEFI boot section #

    -eltorito-alt-boot  
    Starts a second boot entry (for UEFI).

    -e EFI/boot/bootx64.efi  
    Specifies the UEFI boot image.
    This is the UEFI GRUB binary.

    -no-emul-boot  
    Same meaning as above: treat the file as a raw image.

[argument]  iso
    This is the directory containing the modified ISO contents.
    Everything inside this directory becomes the filesystem of the new ISO.


# Confirming installation

1. Check if postinstall.service exists
ls -l /etc/systemd/system/postinstall.service

2. Check if the service was setup
ls -l /etc/systemd/system/multi-user.target.wants/ | grep postinstall

3. Look for provision.sh
ls -l /root/provision.sh
stat /root/provision.sh # must be 0555

4. Look for pterodactyl files
ls -l /root | grep -i ptero
find /var/lib -maxdepth 3 -iname "*ptero*"
find /opt -iname "*ptero*"
find /usr/local -iname "*ptero*"
find / -iname "*.egg"


