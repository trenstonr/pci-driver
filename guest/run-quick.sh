#!/bin/bash
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QEMU="$HERE/../qemu/build/qemu-system-x86_64"

# System OVMF (read-only code) + our writable vars copy.
OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
OVMF_VARS="$HERE/OVMF_VARS.fd"

exec "$QEMU" \
    -M q35 \
    -m 4096 \
    -smp 4 \
    -enable-kvm \
    -cpu host \
    -drive if=pflash,format=raw,unit=0,file="$OVMF_CODE",readonly=on \
    -drive if=pflash,format=raw,unit=1,file="$OVMF_VARS" \
    -drive file="$HERE/noble-cloudimg-amd64.img",if=virtio,format=qcow2 \
    -drive file="$HERE/seed.iso",if=virtio,format=raw \
    -nic user,model=virtio,hostfwd=tcp::22225-:22 \
    -nographic \
    -serial mon:stdio \
    -device cpcidev
