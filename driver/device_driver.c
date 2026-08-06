#define CPCIDEV_VENDOR_ID 0x1234
#define CPCIDEV_DEVICE_ID 0xabcd

#define REG_ID     0x00
#define REG_OP1    0x10
#define REG_OP2    0x14
#define REG_OPCODE 0x18
#define REG_RESULT 0x30

#include <linux/pci.h>

static struct pci_device_id id_table[] = {
	{ PCI_DEVICE(CPCIDEV_VENDOR_ID, CPCIDEV_DEVICE_ID) },
	{ 0, }
};

MODULE_DEVICE_TABLE(pci, id_table);

static int probe (struct pci_dev *pdev, const struct pci_device_id *id) {
	return pci_enable_device(pdev);
}

static void remove(struct pci_dev *pdev) {
	pci_disable_device(pdev);
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
