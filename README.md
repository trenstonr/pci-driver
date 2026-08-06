# pci-driver

Linux PCI driver for a simple, emulated QEMU device (`1234:abcd`). Maps BAR0, writes two operands and an opcode, reads back the result.

```
driver/device_driver.c        kernel module
qemu/hw/misc/custom_pci_dev.c emulated device
qemu.sh                       boots guest with -device cpcidev
```

## Device spec

| Field | Value |
|---|---|
| Vendor / Device | `0x1234` / `0xabcd` |
| Revision | `0x10` |
| Class | `PCI_CLASS_OTHERS` |
| Interrupt pin | INTA |
| MSI | 1 vector, 64-bit, no per-vector mask |
| BAR0 | 1 MiB MMIO, native endian |

| Offset | Name | Access | Reset | Notes |
|---|---|---|---|---|
| `0x00` | `REG_ID` | RO | — | always `0x01234567` |
| `0x10` | `REG_OP1` | RW | `0x02` | operand 1 |
| `0x14` | `REG_OP2` | RW | `0x04` | operand 2 |
| `0x18` | `REG_OPCODE` | RW | `0xaa` | `1`=add, `2`=sub, `3`=mul |
| `0x30` | `REG_RESULT` | RO | `0xbb` | computed on read; `0xff` on bad opcode |

All registers are 32-bits.

## Module

- `id_table` — `PCI_DEVICE(0x1234, 0xabcd)`, exported with `MODULE_DEVICE_TABLE` for autoload.
- `probe()`:
  - `kzalloc` a per-device `struct dev_inst`
  - `pci_enable_device()` — turn on memory decoding
  - `pci_request_region(pdev, 0, ...)` — claim BAR0's physical range
  - `pci_iomap(pdev, 0, 0)` — map it, get a `void __iomem *`
  - `pci_set_drvdata()` — stash the pointer for `remove()`
  - `ioread32(REG_ID)`, then write `3`/`4`/`1` and read `REG_RESULT` → `3 + 4 = 7` in dmesg
- `remove()` — unwind in reverse: `iounmap`, `release_region`, `disable_device`, `kfree`.
- `module_pci_driver()` — generates the init/exit pair.
- `__iomem` pointers are not dereferenceable; `ioread32`/`iowrite32` are what issue the MMIO cycles that trap into QEMU.

## Run

```bash
./qemu.sh                       # host
cd ~/cpcidev && make            # guest
sudo insmod device_driver.ko
dmesg | tail
lspci -nnk -d 1234:abcd
``'
