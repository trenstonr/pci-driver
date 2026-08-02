#!/bin/bash
# One-shot: boot the guest, let cloud-init apply the seed ONE last time (writes
# the ~/cpcidev fstab mount, serial autologin, and SSH key permanently to disk),
# then disable cloud-init so all future boots are fast. Graceful poweroff at end.
cd /home/keahi/repos/pci-driver/guest
pkill -9 -f noble-cloudimg 2>/dev/null; sleep 1
rm -f boot.log

/home/keahi/repos/pci-driver/qemu/build/qemu-system-x86_64 \
    -M q35 -m 4096 -smp 4 -enable-kvm -cpu host \
    -drive if=pflash,format=raw,unit=0,file=/usr/share/OVMF/OVMF_CODE_4M.fd,readonly=on \
    -drive if=pflash,format=raw,unit=1,file=OVMF_VARS.fd \
    -drive file=noble-cloudimg-amd64.img,if=virtio,format=qcow2 \
    -drive file=seed.iso,if=virtio,format=raw \
    -fsdev local,id=driverfs,path=/home/keahi/repos/pci-driver/driver,security_model=none \
    -device virtio-9p-pci,fsdev=driverfs,mount_tag=driver \
    -nic user,model=virtio,hostfwd=tcp::22225-:22 \
    -display none -serial file:boot.log &
QPID=$!
trap 'kill -9 $QPID 2>/dev/null' EXIT

SSH="ssh -i id_cpcidev -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=6 -o BatchMode=yes -p 22225 ubuntu@127.0.0.1"

echo "[*] waiting for SSH..."
up=0
for i in $(seq 1 90); do $SSH true 2>/dev/null && { up=1; break; }; sleep 3; done
[ $up = 1 ] || { echo "FAIL: SSH never came up"; exit 1; }

echo "[*] waiting for cloud-init to finish applying the seed..."
$SSH "sudo cloud-init status --wait" 2>/dev/null | tail -1

echo "=== confirm the mount + fstab entry were written ==="
$SSH "mount | grep -i cpcidev || echo 'NOT MOUNTED'; grep cpcidev /etc/fstab || echo 'NO FSTAB ENTRY'"

echo "=== disabling cloud-init for all future boots ==="
$SSH "sudo touch /etc/cloud/cloud-init.disabled && echo 'cloud-init.disabled created'"
# Also confirm the autologin drop-in persists on disk (independent of cloud-init).
$SSH "test -f /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf && echo 'serial autologin: persisted' || echo 'serial autologin: MISSING'"

echo "=== graceful poweroff ==="
$SSH "sudo poweroff" 2>/dev/null || true
# wait up to 30s for clean shutdown
for i in $(seq 1 15); do kill -0 $QPID 2>/dev/null || { echo 'guest powered off cleanly'; break; }; sleep 2; done
echo "=== DONE ==="
