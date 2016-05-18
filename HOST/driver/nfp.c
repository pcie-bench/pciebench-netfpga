/**
* @file nfp.c
*
* Copyright (c) 2016
* All rights reserved.
*
* as part of the DARPA MRC research programme.
*
* @NETFPGA_LICENSE_HEADER_START@
*
* Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
* license agreements.  See the NOTICE file distributed with this work for
* additional information regarding copyright ownership.  NetFPGA licenses this
* file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
* "License"); you may not use this file except in compliance with the
* License.  You may obtain a copy of the License at:
*
*   http://www.netfpga-cic.org
*
* Unless required by applicable law or agreed to in writing, Work distributed
* under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
* CONDITIONS OF ANY KIND, either express or implied.  See the License for the
* specific language governing permissions and limitations under the License.
*
* @NETFPGA_LICENSE_HEADER_END@
*
*
* @brief "Main" function of the driver. It instantiates the driver, alloc memory, set probe functions
* register interruptions. It also  contains their respectives free functions.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-05
*/

#include "nfp.h"
#include "nfpioctl.h"

#include <linux/sched.h>
#include <linux/kthread.h> // for kthread_create
#include <linux/sched.h>  // for task_struct
#include <linux/time.h>   // for using jiffies 
#include <linux/timer.h>

#ifndef __devexit_p
#define __devexit_p
#endif

#ifndef __devexit
#define __devexit
#endif

#ifndef __devinit
#define __devinit
#endif


MODULE_LICENSE ("GPL");   /**< This driver is released under the GPL license. */
MODULE_AUTHOR ("JF");     /**< Author of the driver Jose Fernando Zazo. */
MODULE_DESCRIPTION ("nfp driver");   /**< Name of the driver. */


static struct pci_device_id pci_id[] = {
  {PCI_DEVICE (PCI_VENDOR_ID_NFP, PCI_DEVICE_ID_NFP) },
  {0}
};  /**< The pci express device that this driver will manage.  */
MODULE_DEVICE_TABLE (pci, pci_id);  /**< Exposes vendor/device in the  device table.  */



/*

Explanation: http://billauer.co.il/blog/2011/05/pcie-pci-express-linux-max-payload-size-configuration-capabilities-tlp-lspci/

  max_payload_size_capable = 1 << ( (DevCapReg & 0x07) + 7); // In bytes

  max_payload_size_in_effect = 1 << ( ( (DevCtrlReg >> 5) & 0x07) + 7); // In bytes


  Constants:

    PCI_CAP_ID_EXP = 0x10

    At 0x34 offset starts the linked list. The first byte is the identifier of the region (were interested in ID = 0x10).
    At 0x04 offset from that region the Device Capabilities Register is present.
    At 0x08 offset from that region the Device Control Register is present.

  Default values

        Device Capabilities Register:

        0x012C8002

        Device Control Register:

        0x00092800

*/
/**
* @brief This function will set the pcie payload to the maximum possible.
*
* @param pdev Pointer to a pci_dev device.
* @param payload The payload that will be set. 0 indicates maximum possible.
*
* @return The possible error code.
*/
static int pci_set_payload (struct pci_dev *dev, uint16_t payload)
{
  int pos, ppos;
  u16 psz;
  u16 dctl, dsz, dcap, dmax;
  struct pci_dev *parent;

  if (! ( (payload >= 128 && payload <= 512) || payload == 0)) {
    return -1;
  }

  parent = dev->bus->self;
  pos = pci_find_capability (dev, PCI_CAP_ID_EXP);

  if (!pos)
    return 0;

  /* Read Device MaxPayload capability and setting */
  pci_read_config_word (dev, pos + PCI_EXP_DEVCTL, &dctl);
  pci_read_config_word (dev, pos + PCI_EXP_DEVCAP, &dcap);
  dsz = (dctl & PCI_EXP_DEVCTL_PAYLOAD) >> 5;   /* Actual configuration */
  dmax = (dcap & PCI_EXP_DEVCAP_PAYLOAD);       /* Maximum payload */
  /* Read Parent MaxPayload setting */
  ppos = pci_find_capability (parent, PCI_CAP_ID_EXP);

  if (!ppos)
    return 0;

  psz = payload == 0 ? dmax : payload >> 8;

  /* If parent payload > device max payload -> error
  * If parent payload > device payload -> set speed
  * If parent payload <= device payload -> do nothing
  */
  if (psz > dmax) {
    return -1;
  } else if (psz > dsz) {
    dev_info (&dev->dev, "Setting MaxPayload to %d\n", 128 << psz);
    pci_write_config_word (dev, pos + PCI_EXP_DEVCTL,
                           (dctl & ~PCI_EXP_DEVCTL_PAYLOAD) +
                           (psz << 5));
  }

  return 0;
}


/*
  http://lkml.iu.edu//hypermail/linux/kernel/0612.1/0224.html,
  http://www.xilinx.com/support/answers/36596.htm
*/
/**
 * @brief pcie_set_readrq - set PCI Express maximum memory read request
 *
 * @param dev PCI device to query
 * @param count maximum memory read count in bytes
 * valid values are 128, 256, 512, 1024, 2048, 4096
 *
 * If possible sets maximum read byte count
 *
 * @return The possible error code.
 */
int pcie_set_readrq (struct pci_dev *dev, int count)
{
  int cap, err = -EINVAL;
  u16 ctl, v;

  if (count < 128 || count > 4096) {
    return -1;
  }

  v = (ffs (count) - 8) << 12;
  cap = pci_find_capability (dev, PCI_CAP_ID_EXP);

  if (!cap) {
    return -1;
  }

  err = pci_read_config_word (dev, cap + PCI_EXP_DEVCTL, &ctl);

  if (err) {
    return -1;
  }

  if ( (ctl & PCI_EXP_DEVCTL_READRQ) != v) {
    ctl &= ~PCI_EXP_DEVCTL_READRQ;
    ctl |= v;
    err = pci_write_config_dword (dev, cap + PCI_EXP_DEVCTL, ctl);
  }

  return 0;
}

/**
* @brief This function will be invoked when a device we want to monitorize is plugged.
* Linux kernel invokes this function.
*
* @param pdev Pointer to a pci_dev device.
* @param id The identifier of the plugged device.
*
* @return The possible error code.
*/
static int __devinit nfp_probe (struct pci_dev *pdev, const struct pci_device_id *id)
{
  int ret = -ENODEV;
  struct nfp_card *card = NULL;

  /* Initialize structure */
  card = kmalloc (sizeof (struct nfp_card), GFP_KERNEL);
  if (card == NULL) {
    printk (KERN_ERR "nfp: Could not obtain enough memory\n");
    return -ENODEV;
  }
  memset (card, 0, sizeof (struct nfp_card));

  card->pdev  =  pdev;
  sema_init (&card->sem_op, 1);   /* We accept one IOCTL operation per time. No op has yet started. */

  /* Enable device */
  if ( (ret = pci_enable_device (pdev))) {
    printk (KERN_ERR "nfp: Unable to enable the PCI device!\n");
    ret = -ENODEV;
    return ret;
  }

  if (pci_set_payload (pdev, 128)) {
    printk (KERN_ERR "nfp: Unable to adjust the PCIe payload!\n");
    goto  err_out_disable_device;
  }

  if (pcie_set_readrq (pdev, 4096)) {
    printk (KERN_ERR "nfp: Unable to adjust the PCIe read request!\n");
    goto  err_out_disable_device;
  }

  /* Set the dma mask to 64Bit */
  if (!pci_set_dma_mask (pdev, DMA_BIT_MASK (64))) {
    if (pci_set_consistent_dma_mask (pdev, DMA_BIT_MASK (64))) {
      printk (KERN_INFO "nfp: unable to set adapter  PCI DMA mask to 64Bit\n");
      goto err_out_disable_device;
    }
  } else {
    printk (KERN_INFO "nfp: unable to set adapter  PCI DMA mask to 64Bit\n");
    goto err_out_disable_device;
  }

  /* Save a pointer to "card" in the device (private pointer of struct pci_dev) */
  pci_set_drvdata (pdev, card);
  pci_set_master (pdev);
  /* Enable ioctl operations */
  ret = nfpioctl_probe (pdev, card);

  if (ret < 0) {
    printk (KERN_ERR "nfp: failed to register cdev\n");
    goto err_out_ioctl;
  }

  /* Get BAR0 and "alloc" memory */
  if (! (pci_resource_flags (pdev, 0) & IORESOURCE_MEM)) {
    printk (KERN_ERR "nfp: Impossible to access BAR0\n");
    goto err_out_ioctl;
  } else {
    ret = pci_request_regions (pdev, "nfp");

    if (ret) {
      printk (KERN_ERR "nfp: failed to register BAR0\n");
      goto err_out_ioctl;
    }

    card->bar0 = pci_iomap (pdev, 0, pci_resource_len (pdev, 0));
    printk (KERN_INFO "nfp: register BAR0\n");

    card->bar1 = pci_iomap (pdev, 1, pci_resource_len (pdev, 0));
    if (card->bar1) {
      printk (KERN_INFO "nfp: register BAR1\n");
    }

    card->bar2 = pci_iomap (pdev, 2, pci_resource_len (pdev, 0));
    if (card->bar2) {
      printk (KERN_INFO "nfp: register BAR2\n");
    }
  }


  card->dma = card->bar0 + (DMA_OFFSET * 8); //Bar 0 uses a 0x200 offset of 64 bit words.

  card->mmap_info.page_list = pci_alloc_consistent(pdev, MAX_PAGES * PAGE_SIZE, &card->mmap_info.dma_handle);
  if (card->mmap_info.page_list == NULL) {
    printk (KERN_ERR "nfp: Can not alloc a buffer\n");
    goto err_iface;
  }
  printk (KERN_INFO "nfp: device ready\n");

  return ret;

err_iface:
  pci_iounmap (pdev, card->bar0);
  if (card->bar1) pci_iounmap (pdev, card->bar1);
  if (card->bar2) pci_iounmap (pdev, card->bar2);

  pci_release_regions (pdev);
  pci_set_drvdata (pdev, NULL);
  pci_clear_master (pdev);
  pci_disable_device (pdev);
  nfpioctl_remove (pdev, card);
err_out_ioctl:
  kfree (card);
err_out_disable_device:
  pci_disable_device (pdev);
  pci_set_drvdata (pdev, NULL);
  return ret;
}

/**
* @brief It the device is going to be removed  or the driver calls the pci_unregister_driver
* function, this routine will free all the resources preallocated.
*
* @param pdev A pointer to the device that is going to be extracted.
*
* @return No return.
*/
static void __devexit nfp_remove (struct pci_dev *pdev)
{
  struct nfp_card *card;
  /* Do the operations of the attach in reverse order.  */
  card = (struct nfp_card*) pci_get_drvdata (pdev);
  printk (KERN_INFO "nfp: releasing private memory\n");

  if (card) {
    //__free_pages(card->mmap_info.page_list, LOG2_MAX_PAGES ); card->mmap_info.page_list = NULL;
    pci_free_consistent(pdev, MAX_PAGES * PAGE_SIZE, card->mmap_info.page_list, card->mmap_info.dma_handle);
    //kfree(card->mmap_info.page_list);
    printk (KERN_INFO "nfp: disabling device\n");
    nfpioctl_remove (pdev, card);

    pci_iounmap (pdev, card->bar0);
    if (card->bar1) pci_iounmap (pdev, card->bar1);
    if (card->bar2) pci_iounmap (pdev, card->bar2);

    pci_release_regions (pdev);
    pci_set_drvdata (pdev, NULL);
    pci_clear_master (pdev);
    pci_disable_device (pdev);
    kfree (card);
  }
}



/**
* @brief This function will be invoked when a device chage its state from suspend to active.
*
* @param pdev A pointer to the device structure.
*
* @return The possible error code.
*/
static int nfp_resume (struct pci_dev * pdev)
{
  pci_set_power_state (pdev, PCI_D0);
  pci_restore_state (pdev);
  return 0;
}


/**
* @brief This function will be invoked when a device chage its state from active to suspend.
*
* @param pdev A pointer to the device structure.
* @param mstate has two fields. event ("major"), and flags.  Some
* drivers may need to deal with special cases based on the actual type
* of suspend operation being done at the system level. It is not the case.
*
* @return The possible error code.
*/
static int nfp_suspend (struct pci_dev * pdev, pm_message_t mstate)
{
  pci_save_state (pdev);
  pci_set_power_state (pdev, pci_choose_state (pdev, mstate));
  return 0;
}


/**
* @brief Alert about possible erros in the pci communication.
*
* @param dev A pointer to the device structure.
* @param state An informative message about the error.
*
* @return PCI_ERS_RESULT_RECOVERED.
*/
pci_ers_result_t nfp_pcie_error (struct pci_dev *dev, enum pci_channel_state state)
{
  printk (KERN_ALERT "nfp: PCIe error: %d\n", state);
  return PCI_ERS_RESULT_RECOVERED;
}


/**
* @brief Indicate which function will manage the errors.
*/
static struct pci_error_handlers pcie_err_handlers = {
  .error_detected = nfp_pcie_error
};


/**
* @brief Configure pci associated functions.
*/
static struct pci_driver pci_driver = {
  .name = "nfp",
  .id_table = pci_id,
  .probe = nfp_probe,
  .remove = __devexit_p (nfp_remove),
  .suspend  = nfp_suspend,
  .resume   = nfp_resume,
  .err_handler = &pcie_err_handlers
};

#ifdef USE_KERNEL_AFFINITY
/**
* @brief This function invoke the scheduler to use the indicate CPU.
*
* @return The possible error code.
*/
static void set_affinity (void)
{
  DECLARE_BITMAP (cpu_bits, NR_CPUS);
  cpu_bits[0] = CPU_AFFINITY_MASK;

  cpu_bits[0] = CPU_AFFINITY_MASK;
  sched_setaffinity (0, to_cpumask (cpu_bits));     /* Set affinity of tihs process to */
  /* the defined mask, i.e. only 0. */
}
#endif

/**
* @brief On insmod this function will be invoked.
*
* @return The possible error code.
*/
static int __init nfp_init (void)
{
  printk (KERN_INFO "nfp: module loaded\n");
#ifdef USE_KERNEL_AFFINITY
  set_affinity();  /* Set the affinity of the module. */
#endif
  return pci_register_driver (&pci_driver);
}


/**
* @brief On rmmod this function will be invoked
*
* @return No return.
*/
static void __exit nfp_exit (void)
{
  pci_unregister_driver (&pci_driver);
  printk (KERN_INFO "nfp: module unloaded\n");
}

module_init (nfp_init);   /**< Indicated nfp_init is the "insmod invoke function"  */
module_exit (nfp_exit);   /**< Indicated nfp_exit is the "rmmod invoke function"  */

