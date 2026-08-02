#!/bin/bash
# Boot the Ubuntu guest with our custom PCI device (cpcidev / 1234:abcd) attached,
# and share ./driver into the guest over virtio-9p so you edit on the host and
# build inside the guest on the very same files (mounted at ~/cpcidev).
#
# Run this in your own terminal: ./qemu.sh
# Interactive serial console (auto-login as 'ubuntu'). Ctrl-a x to quit QEMU.
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QEMU="$ROOT/qemu/build/qemu-system-x86_64"
G="$ROOT/guest"
DRV="$ROOT/driver"

OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
OVMF_VARS="$G/OVMF_VARS.fd"

# Sanity checks with clear messages.
for f in "$QEMU" "$G/noble-cloudimg-amd64.img" "$OVMF_CODE"; do
    [ -e "$f" ] || { echo "MISSING: $f" >&2; exit 1; }
done
mkdir -p "$DRV"
# Fresh writable copy of the UEFI vars if it's not there yet.
[ -e "$OVMF_VARS" ] || cp /usr/share/OVMF/OVMF_VARS_4M.fd "$OVMF_VARS"

# Attach the cloud-init seed only while it still exists. After you run
# 'sudo touch /etc/cloud/cloud-init.disabled' in the guest you can delete
# guest/seed.iso and boots skip cloud-init entirely.
SEED_ARGS=()
[ -e "$G/seed.iso" ] && SEED_ARGS=(-drive file="$G/seed.iso",if=virtio,format=raw)

echo "Booting guest with -device cpcidev ..."
echo "  driver/ is shared into the guest at ~/cpcidev (virtio-9p, tag 'driver')"
echo "  SSH from another terminal:"
echo "    ssh -i $G/id_cpcidev -o StrictHostKeyChecking=no -p 22225 ubuntu@127.0.0.1"
echo "  Quit QEMU: Ctrl-a x"
echo

exec "$QEMU" \
    -M q35 \
    -m 4096 \
    -smp 4 \
    -enable-kvm \
    -cpu host \
    -drive if=pflash,format=raw,unit=0,file="$OVMF_CODE",readonly=on \
    -drive if=pflash,format=raw,unit=1,file="$OVMF_VARS" \
    -drive file="$G/noble-cloudimg-amd64.img",if=virtio,format=qcow2 \
    "${SEED_ARGS[@]}" \
    -fsdev local,id=driverfs,path="$DRV",security_model=none \
    -device virtio-9p-pci,fsdev=driverfs,mount_tag=driver \
    -nic user,model=virtio,hostfwd=tcp::22225-:22 \
    -nographic \
    -serial mon:stdio \
    -device cpcidev
