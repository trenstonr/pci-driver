#!/bin/bash
# Self-contained verification: boot guest, wait for cloud-init, check the 9p
# share auto-mounted, build the skeleton driver on it, insmod, confirm bind.
# qemu lives only for this script's lifetime and is killed at the end.
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
for i in $(seq 1 90); do
  if $SSH true 2>/dev/null; then up=1; break; fi
  sleep 3
done
[ $up = 1 ] || { echo "FAIL: SSH never came up"; exit 1; }
echo "[*] SSH up. waiting for cloud-init to finish..."
$SSH "sudo cloud-init status --wait" 2>/dev/null | tail -1

echo "=== 9p mount ==="
$SSH "mount | grep -i cpcidev || echo 'NOT MOUNTED'"
echo "=== shared files visible in guest ==="
$SSH "ls -la ~/cpcidev"
echo "=== install headers (may take a bit) ==="
$SSH "sudo apt-get -qq update && sudo apt-get -qq install -y build-essential linux-headers-\$(uname -r)" 2>&1 | tail -2
echo "=== build the driver on the shared folder ==="
$SSH "cd ~/cpcidev && make 2>&1 | tail -5"
echo "=== insmod + confirm bind ==="
$SSH "cd ~/cpcidev && sudo insmod device_driver.ko && dmesg | tail -3 && echo '---' && lspci -nnk -d 1234:abcd && sudo rmmod device_driver"
echo "=== DONE ==="
