// SPDX-License-Identifier: GPL-2.0
/*
 * Skeleton driver for the QEMU "cpcidev" custom PCI device (1234:abcd).
 *
 * This is a minimal, COMPILING starting point: it binds to the device and
 * maps BAR0 so you have MMIO access. The actual device logic (the op1/op2/
 * opcode/result protocol, and however you want to expose it to userspace --
 * char device + ioctl, sysfs, etc.) is left for you to implement where the
 * TODOs are.
 *
 * Device register map (offsets into BAR0):
 *   0x00  ID     (R)  -> always 0x01234567   (presence check)
 *   0x10  op1    (RW)
 *   0x14  op2    (RW)
 *   0x18  opcode (RW)  1=add, 2=sub, 3=mul
 *   0x30  result (R)   reading triggers the compute; bad opcode -> 0xff
 * All register accesses are 32-bit.
 */
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/kernel.h>
#include <linux/init.h>

#define CPCIDEV_VENDOR_ID 0x1234
#define CPCIDEV_DEVICE_ID 0xabcd

#define REG_ID     0x00
#define REG_OP1    0x10
#define REG_OP2    0x14
#define REG_OPCODE 0x18
#define REG_RESULT 0x30

struct cpcidev {
	struct pci_dev *pdev;
	void __iomem   *mmio;   /* BAR0 */
};

static int cpcidev_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	struct cpcidev *dev;
	int err;
	u32 magic;

	dev = devm_kzalloc(&pdev->dev, sizeof(*dev), GFP_KERNEL);
	if (!dev)
		return -ENOMEM;
	dev->pdev = pdev;

	err = pcim_enable_device(pdev);
	if (err)
		return err;

	err = pcim_iomap_regions(pdev, BIT(0), KBUILD_MODNAME);
	if (err)
		return err;
	dev->mmio = pcim_iomap_table(pdev)[0];

	pci_set_drvdata(pdev, dev);

	magic = ioread32(dev->mmio + REG_ID);
	dev_info(&pdev->dev, "cpcidev bound; BAR0 ID reg = 0x%08x\n", magic);

	/* TODO: your init here -- register a char device / ioctl interface,
	 * drive op1/op2/opcode and read result, etc. */

	return 0;
}

static void cpcidev_remove(struct pci_dev *pdev)
{
	/* TODO: tear down whatever you set up in probe.
	 * (devm_/pcim_ resources are freed automatically.) */
	dev_info(&pdev->dev, "cpcidev removed\n");
}

static const struct pci_device_id cpcidev_ids[] = {
	{ PCI_DEVICE(CPCIDEV_VENDOR_ID, CPCIDEV_DEVICE_ID) },
	{ 0, }
};
MODULE_DEVICE_TABLE(pci, cpcidev_ids);

static struct pci_driver cpcidev_driver = {
	.name     = KBUILD_MODNAME,
	.id_table = cpcidev_ids,
	.probe    = cpcidev_probe,
	.remove   = cpcidev_remove,
};
module_pci_driver(cpcidev_driver);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Driver for the QEMU cpcidev custom PCI device");
