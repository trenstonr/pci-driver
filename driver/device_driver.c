#define CPCIDEV_VENDOR_ID 0x1234
#define CPCIDEV_DEVICE_ID 0xabcd

#define REG_ID     0x00
#define REG_OP1    0x10
#define REG_OP2    0x14
#define REG_OPCODE 0x18
#define REG_RESULT 0x30

#define CPCIDEV_BAR 0

#include <linux/pci.h>
#include <linux/slab.h>

struct dev_inst {
	void __iomem *bar0;
};

static struct pci_device_id id_table[] = {
	{ PCI_DEVICE(CPCIDEV_VENDOR_ID, CPCIDEV_DEVICE_ID) },
	{ 0, }
};

MODULE_DEVICE_TABLE(pci, id_table);

static int probe (struct pci_dev *pdev, const struct pci_device_id *id) {
	struct dev_inst *dv = kzalloc(sizeof(*dv), GFP_KERNEL);

	pci_enable_device(pdev);
	
	// claim BAR0 physical address range for this driver
	pci_request_region(pdev, CPCIDEV_BAR, "super_cool_pci_device");

	// map BAR0 physical range into kernel va space
	dv->bar0 = pci_iomap(pdev, CPCIDEV_BAR, 0);

	// store dv pointer in pdev for future use
	pci_set_drvdata(pdev, dv);

	return 0;
}

static void remove(struct pci_dev *pdev) {
	// retrieve stashed pointer
	struct dev_inst *dv = pci_get_drvdata(pdev);

	// unmap virtual mapping
	pci_iounmap(pdev, dv->bar0);

	// unclaim BAR0 address range
	pci_release_region(pdev, CPCIDEV_BAR);

	pci_disable_device(pdev);

	// just free the struct
	kfree(dv);
}
 
static struct pci_driver driva = {
	.name = "super_cool_pci_device",
	.id_table = id_table,
	.probe = probe,
	.remove = remove,
};

module_pci_driver(driva);


MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("RANDOM DESCRIPTION");
