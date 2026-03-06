#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# This script must run with root privileges.
# ISO extraction produces root-owned, read-only files, and
# modifying them requires elevated permissions.
# ============================================================

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo or as root."
    echo "Example: sudo ./create_iso.sh"
    exit 1
fi


#############################################
# CONFIGURATION
#############################################
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

output_path="$BASE_DIR/final_iso"
starting_path="$BASE_DIR/final_iso/original_copied_in_here_for_modding"
backup_location="$BASE_DIR/unpacked-starting_iso/Ubuntu_server"
branches_path="$BASE_DIR/branches"
filename_prefix="pterodactyl_ubuntu_test_"

#############################################
# FUNCTION: Select branch
#############################################

choice_fun() {
    echo "Available provisioning branches:"
    echo

    mapfile -t branches < <(ls -1 "$branches_path")

    if [[ ${#branches[@]} -eq 0 ]]; then
        echo "No branches found in $branches_path"
        exit 1
    fi

    local i=1
    for b in "${branches[@]}"; do
        echo "  $i) $b"
        ((i++))
    done

    echo
    read -rp "Select a branch number: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#branches[@]} )); then
        echo "Invalid selection"
        exit 1
    fi

    selected_branch="${branches[$((choice-1))]}"
    branch_path="$branches_path/$selected_branch"

    echo "Selected branch: $selected_branch"
}

#############################################
# FUNCTION: Sanitize hostname
#############################################

sanitize_hostname() {
    # Lowercase, alphanumeric and hyphens only, max 63 chars, no leading/trailing hyphen
    # RFC 1123 compliant: a-z, 0-9, hyphen; cannot start/end with hyphen
    local name="$1"
    
    # Lowercase
    name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
    
    # Keep only alphanumeric and hyphens
    name=$(printf '%s' "$name" | tr -cd '[:alnum:]-')
    
    # Remove leading hyphens
    while [[ "$name" == -* ]]; do
        name="${name#-}"
    done
    
    # Remove trailing hyphens
    while [[ "$name" == *- ]]; do
        name="${name%-}"
    done
    
    # Truncate to 63 characters (RFC 1123 limit)
    name="${name:0:63}"
    
    # Fallback if empty or only hyphens were provided
    if [[ -z "$name" ]]; then
        name="ubuntu"
    fi
    
    printf '%s' "$name"
}

#############################################
# FUNCTION: Collect user credentials
#############################################

collect_credentials() {
    echo "Enter the credentials that will be injected into the provisioning script:"
    echo

    read -rp "Panel admin email: " panel_email
    read -rp "Panel admin username: " panel_user
    read -rsp "Panel admin password: " panel_pass; echo
    read -rsp "Database password: " db_pass; echo

    # Validate inputs aren't empty
    [[ -z "$panel_email" ]] && { echo "Email cannot be empty"; exit 1; }
    [[ -z "$panel_user" ]] && { echo "Username cannot be empty"; exit 1; }
    [[ -z "$panel_pass" ]] && { echo "Panel password cannot be empty"; exit 1; }
    [[ -z "$db_pass" ]] && { echo "Database password cannot be empty"; exit 1; }

    # Hash the panel password for system user (Ubuntu-compatible SHA-512)
    hashed_user_pass=$(mkpasswd -m sha-512 "$panel_pass")
    
    # Generate sanitized hostname from username
    safe_hostname=$(sanitize_hostname "$panel_user")

    # Export all values for sed replacement 
    export panel_email panel_user panel_pass db_pass hashed_user_pass safe_hostname
}

#############################################
# FUNCTION: Determine next build number
#############################################

next_build_number() {
    mkdir -p "$output_path"

    # shellcheck disable=SC2010
    mapfile -t existing < <(ls -1 "$output_path" | grep -E '^[0-9]{4}$' || true)

    if [[ ${#existing[@]} -eq 0 ]]; then
        build_num="0001"
    else
        last=$(printf "%s\n" "${existing[@]}" | sort -n | tail -1)
        build_num=$(printf "%04d" $((10#$last + 1)))
    fi

    build_dir="$output_path/$build_num"
    mkdir -p "$build_dir"

    output_iso="$output_path/${filename_prefix}${build_num}.iso"
}

#############################################
# FUNCTION: Find and extract Ubuntu ISO
#############################################

extract_iso() {
    echo "Searching for Ubuntu Server ISO in: $BASE_DIR"

    # Find ISO files in the working directory
    mapfile -t iso_files < <(find "$BASE_DIR" -maxdepth 1 -type f -name "*.iso")

    if [[ ${#iso_files[@]} -eq 0 ]]; then
        echo "ERROR: No ISO files found in $BASE_DIR"
        exit 1
    fi

    if [[ ${#iso_files[@]} -gt 1 ]]; then
        echo "Multiple ISO files found:"
        local i=1
        for iso in "${iso_files[@]}"; do
            echo "  $i) $(basename "$iso")"
            ((i++))
        done
        echo
        read -rp "Select ISO number: " choice

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#iso_files[@]} )); then
            echo "Invalid selection"
            exit 1
        fi

        selected_iso="${iso_files[$((choice-1))]}"
    else
        selected_iso="${iso_files[0]}"
    fi

    echo "Using ISO: $(basename "$selected_iso")"
    echo "Extracting ISO to: $backup_location"

    # ensure parent dir and old contents are writable and removable 
    parent_dir="$(dirname "$backup_location")" 
    mkdir -p "$parent_dir" 
    rm -rf "$backup_location" 
    mkdir -p "$backup_location"

    #old line
    # xorriso -osirrox on -indev "$selected_iso" -extract / "$backup_location"

    # extract ISO with permissive flags so files are owned/writable by current user
    xorriso -osirrox on -indev "$selected_iso" -extract / "$backup_location"

    echo "ISO extraction complete."
}

#############################################
# FUNCTION: Prepare working directory
#############################################

prepare_workdir() {
    echo "Preparing working directory..."

    rm -rf "$starting_path"
    mkdir -p "$starting_path"

    cp -a "$backup_location/". "$starting_path/"
}

#############################################
# FUNCTION: Inject autoinstall + postinstall
#############################################

inject_files() {
    echo "Injecting autoinstall and postinstall files..."

    mkdir -p "$starting_path/autoinstall"
    cp "$branch_path/user-data.yaml" "$starting_path/autoinstall/user-data"
    touch "$starting_path/autoinstall/meta-data"

    mkdir -p "$starting_path/postinstall"
    cp "$branch_path/provision.sh" "$starting_path/postinstall/provision.sh"
    cp "$branch_path/postinstall.service" "$starting_path/postinstall/postinstall.service"
}

#############################################
# FUNCTION: Replace placeholders in provision.sh and user-data
#############################################

replace_placeholders() {
    local prov="$starting_path/postinstall/provision.sh"
    local userdata="$starting_path/autoinstall/user-data"

    # Verify files exist
    [[ -f "$prov" ]] || { echo "ERROR: provision.sh not found at $prov"; exit 1; }
    [[ -f "$userdata" ]] || { echo "ERROR: user-data not found at $userdata"; exit 1; }

    echo "Replacing placeholders in provision.sh..."

    sed -i "s|replace_panel_email|${panel_email//|/\\|}|g" "$prov"
    sed -i "s|replace_panel_username|${panel_user//|/\\|}|g" "$prov"
    sed -i "s|replace_panel_password|${panel_pass//|/\\|}|g" "$prov"
    sed -i "s|replace_db_password|${db_pass//|/\\|}|g" "$prov"

    echo "Replacing placeholders in user-data..."

    sed -i "s|replace_me_hostname|${safe_hostname//|/\\|}|g" "$userdata"
    sed -i "s|replace_me_username|${panel_user//|/\\|}|g" "$userdata"
    sed -i "s|replace_me_password|${hashed_user_pass//|/\\|}|g" "$userdata"

    echo "Placeholder replacement complete."
    echo "  Hostname: $safe_hostname"
    echo "  Username: $panel_user"
}


#############################################
# FUNCTION: Patch GRUB
#############################################

patch_grub() {
    echo "Patching GRUB..."

    for grubfile in "$starting_path/boot/grub/grub.cfg" "$starting_path/boot/grub/loopback.cfg"; do
        if [[ -f "$grubfile" ]]; then
            sed -i 's|linux\s\+/casper/vmlinuz|linux /casper/vmlinuz quiet autoinstall ds=nocloud\\;s=/cdrom/autoinstall/|' "$grubfile"
        else
            echo "WARNING: $grubfile not found, skipping GRUB patch"
        fi
    done
}

#############################################
# FUNCTION: Build ISO
#############################################

build_iso() {
    echo "Building ISO: $output_iso"

    xorriso -as mkisofs \
        -r -V "UBUNTU_AUTOINSTALL" \
        -o "$output_iso" \
        -J -l -cache-inodes -partition_offset 16 \
        -b boot/grub/i386-pc/eltorito.img \
        -c boot.catalog \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot \
        -e EFI/boot/bootx64.efi \
        -no-emul-boot \
        "$starting_path"

    echo "ISO created successfully."
}

#############################################
# FUNCTION: Archive branch used
#############################################

archive_branch() {
    echo "Archiving branch files..."

    mkdir -p "$build_dir/branch_used"
    cp "$branch_path/"* "$build_dir/branch_used/"
}

#############################################
# FUNCTION: Cleanup files
#############################################

cleanup_iso_files() {
    rm -rf "$starting_path"
    rm -rf "$backup_location"

    echo "Cleaned up excess files."
}

#############################################
# MAIN SCRIPT
#############################################

choice_fun
collect_credentials
next_build_number
extract_iso    
prepare_workdir
inject_files
replace_placeholders
patch_grub
build_iso
archive_branch
cleanup_iso_files

echo
echo "Build complete."
echo "ISO: $output_iso"
echo "Build directory: $build_dir"
