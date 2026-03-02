#!/usr/bin/env bash
set -euo pipefail

#############################################
# CONFIGURATION
#############################################
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

output_path="$BASE_DIR/final_iso"
starting_path="$BASE_DIR/final_iso/original_copied_in_here_for_modding"
backup_location="$BASE_DIR/unpacked-starting_iso/Ubuntu_server"
branches_path="$BASE_DIR/branches"
filename_prefix="ubuntu_test_"

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
# FUNCTION: Collect user credentials
#############################################

collect_credentials() {
    echo "Enter the credentials that will be injected into the provisioning script:"
    echo

    read -rp "Panel admin email: " panel_email
    read -rp "Panel admin username: " panel_user
    read -rsp "Panel admin password: " panel_pass; echo
    read -rsp "Database password: " db_pass; echo

    # Export so sed can use them easily
    export panel_email panel_user panel_pass db_pass
}


#############################################
# FUNCTION: Determine next build number
#############################################

next_build_number() {
    mkdir -p "$output_path"

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

    rm -rf "$backup_location"
    mkdir -p "$backup_location"

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
# FUNCTION: Replace placeholders in provision.sh
#############################################

replace_placeholders() {
    local prov="$starting_path/postinstall/provision.sh"

    echo "Replacing placeholders in provision.sh..."

    sed -i "s|replace_panel_email|$panel_email|g" "$prov"
    sed -i "s|replace_panel_username|$panel_user|g" "$prov"
    sed -i "s|replace_panel_password|$panel_pass|g" "$prov"
    sed -i "s|replace_db_password|$db_pass|g" "$prov"
}


#############################################
# FUNCTION: Patch GRUB
#############################################

patch_grub() {
    echo "Patching GRUB..."

    for grubfile in "$starting_path/boot/grub/grub.cfg" "$starting_path/boot/grub/loopback.cfg"; do
        sed -i 's|linux\s\+/casper/vmlinuz|linux /casper/vmlinuz quiet autoinstall ds=nocloud\\;s=/cdrom/autoinstall/|' "$grubfile"
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

echo
echo "Build complete."
echo "ISO: $output_iso"
echo "Build directory: $build_dir"
