/**
* @file nfpioctl.c
*
* Copyright (c) 2016
* All rights reserved.
*
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
* @brief This module implements the registration of the char device and the IOCTL handle routine.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-05
*/
#include "nfp_types.h"
#include "nfpioctl.h"
#include "nfpdma.h"
#include "nfpmem.h"

#include "reg.h"
#include <linux/pagemap.h>
#include <linux/sched.h>
#include <linux/fs_struct.h>
#include <linux/version.h>



/**
* @brief Invoked function when the user makes an open over the char device.
*
* @param inode A pointer to the inode struct.
* @param filp  A pointer to the file struct. We will save the struct nfp_card in its
* private pointer.
*
* @return The possible error code.
*/
static int nfp_open (struct inode *inode, struct file *filp)
{
  struct nfp_card *card = (struct nfp_card *) container_of (inode->i_cdev, struct nfp_card, cdev);
  filp->private_data = card;

  return 0;
}

/**
* @brief Invoked function on close.
*
* @param inode A pointer to the inode struct.
* @param filp  A pointer to the file struct. We will erase the struct nfp_card in its
* private pointer.
*
* @return The possible error code.
*/
static int nfp_release (struct inode *inode, struct file *filp)
{
  filp->private_data = NULL;
  return 0;
}

/* The read operation doesnt do anything (/dev/null)  */
static ssize_t nfp_read (struct file *file,
                         char *buffer,
                         size_t length,
                         loff_t * offset)
{
  return 0;
}

/* The write operation doesnt do anything (/dev/null) */
static ssize_t nfp_write (struct file *filp, const char *buffer, size_t len, loff_t * off)
{
  return len;
}

/**
* @brief When an IOCTL is received this function will process it.
*
* @param f   The file pointer struct associated with the char device.
* @param cmd The command of the IOCTl operation.
* @param arg The argument the user passed to this function.
*
* @return The possible error code.
*/
long nfp_ioctl (struct file *f, unsigned int cmd, unsigned long arg)
{
  struct nfp_card *card = (struct nfp_card *) f->private_data;
  struct reg32 r;
  u64 timeout;
  void *pInArg = NULL;
  struct dma_descriptor_sw dd;
  struct dma_buffer   db;

  /* Check if it is a correct IOCTL  */
  if (_IOC_TYPE (cmd) != IOCTL_MAGIC_NUMBER) return -ENOTTY;     /* Unexpected code */
  if (_IOC_NR (cmd) > IOC_MAXNR) return -ENOTTY;                 /* Unexpected number */

  pInArg = (void __user *) arg;


  if (down_interruptible (&card->sem_op)) {   /* Block other IOCTL operations. */
    up (&card->sem_op);
    return -ERESTARTSYS;
  }

  /* Copy the user struct into kernel space  */

  if (cmd == NFPIOC_READ_32 || cmd == NFPIOC_WRITE_32) {
    if (copy_from_user (&r, pInArg, sizeof (struct reg32))) {
      up (&card->sem_op);
      printk (KERN_ERR "nfp: user variables cannot be accessed");
      return -EFAULT;
    }
  } else if (cmd == NFPIOC_WINDOW_SIZE) {
    if (copy_from_user (&timeout, pInArg, sizeof (u64))) {
      up (&card->sem_op);
      printk (KERN_ERR "nfp: user variables cannot be accessed");
      return -EFAULT;
    }
  } else if (cmd == NFPIOC_WRITE_DMA_DESCRIPTOR || cmd == NFPIOC_READ_DMA_DESCRIPTOR) {
    if (copy_from_user (&dd, pInArg, sizeof (struct dma_descriptor_sw))) {
      up (&card->sem_op);
      printk (KERN_ERR "nfp: user variables cannot be accessed");
      return -EFAULT;
    }
  } else if (cmd == NFPIOC_REGISTER_BUFFER) {
    if (copy_from_user (&db, pInArg, sizeof (struct dma_buffer))) {
      up (&card->sem_op);
      printk (KERN_ERR "nfp: user variables cannot be accessed");
      return -EFAULT;
    }
  }


  /* Select the correct operation.  */
  switch (cmd) {
  case NFPIOC_WINDOW_SIZE:
    dma_set_window_size(timeout,  card);
    break;

  case NFPIOC_WRITE_32:
    WriteReg32 (&r, card);
    break;

  case NFPIOC_READ_32:
    ReadReg32 (&r, card);

    if (copy_to_user (pInArg, &r, sizeof (struct reg32))) {
      printk (KERN_ERR "nfp: It was impossible to access user variable");
    }

    break;

  case NFPIOC_WRITE_DMA_DESCRIPTOR:
    if (card->buffer.virtual == NULL) { // Mmap buffer
      dd.address = (u64) ( (u8 *) card->mmap_info.page_list +  (card->mmap_info.first + (u64)dd.address)); // Use the page indicated by the user (and calculate the kernel direction from the internal buffer)
    } else if ((dd.address + dd.length) / card->buffer.page_size == dd.address / card->buffer.page_size) { //We do not exceed a huge page (take care of offsets)
      dd.address = card->buffer.page_address[(u64)dd.address / card->buffer.page_size] + (u64)dd.address % card->buffer.page_size;
    } else {
      printk(KERN_ERR "nfp: Error while computing the physical address of the memory");
      break;
    }

    writeDMADescriptor(&dd, card);
    break;

  case NFPIOC_READ_DMA_DESCRIPTOR:
    if (card->buffer.virtual == NULL) { // Mmap buffer
      dd.address = (u64) ( (u8 *) card->mmap_info.page_list + (card->mmap_info.first + (u64)dd.address)); // Use the page indicated by the user (and calculate the kernel direction from the internal buffer)
    } else if ((dd.address + dd.length) / card->buffer.page_size == dd.address / card->buffer.page_size) { //We do not exceed a huge page (take care of offsets)
      dd.address = card->buffer.page_address[(u64)dd.address / card->buffer.page_size] + (u64)dd.address % card->buffer.page_size;
    } else {
      printk(KERN_ERR "nfp: Error while computing the physical address of the memory");
      break;
    }

    readDMADescriptor(&dd, card);

    if (copy_to_user (pInArg, &dd, sizeof (struct dma_descriptor_sw))) {
      printk (KERN_ERR "nfp: It was impossible to access user variable");
    }

    break;

  case NFPIOC_REGISTER_BUFFER:
    reg_hugemem(card, &db);
    break;

  case NFPIOC_UNREGISTER_BUFFER:
    unreg_hugemem(card);
    break;

    break;

  default:
    printk (KERN_INFO "nfp: IOCTL command not recognized %d\n", cmd);
  }

  up (&card->sem_op);
  return 0;
}




/* keep track of how many times it is mmapped */
void mmap_close(struct vm_area_struct *vma)
{
  struct nfp_card *card = (struct nfp_card *) vma->vm_private_data;

  int npages  = (vma->vm_end - vma->vm_start) / PAGE_SIZE;
  if ( npages * PAGE_SIZE != (vma->vm_end - vma->vm_start)  ) npages++;


  if (card->mmap_info.first == card->mmap_info.last) {
    card->mmap_info.active = 0;
  } else {
    card->mmap_info.first = (card->mmap_info.first + npages) % MAX_PAGES;
  }
}

struct vm_operations_struct mmap_vm_ops = {
  .close =     mmap_close
};



int mmap_kmem(struct file *f, struct vm_area_struct *vma)
{
  int npages  = (vma->vm_end - vma->vm_start) / PAGE_SIZE;
  void *p;
  int ret, i;
  struct nfp_card *card = (struct nfp_card *) f->private_data;

  vma->vm_ops = &mmap_vm_ops;
  vma->vm_private_data =  f->private_data;

  if ( npages * PAGE_SIZE != (vma->vm_end - vma->vm_start)  ) npages++;


  for (i = 0; i < npages; i++) {
    if ((card->mmap_info.last + i + 1) % MAX_PAGES == card->mmap_info.first) { // No free elements
      return -EAGAIN;
    }
  }
  // Pick a page from the list
  p = (u8 *)card->mmap_info.page_list + PAGE_SIZE * card->mmap_info.last;
  ret = (u64) virt_to_page(p);

  if ((ret = remap_pfn_range(vma, vma->vm_start, virt_to_phys(p) >> PAGE_SHIFT, vma->vm_end - vma->vm_start, vma->vm_page_prot)) < 0) {
    return -EAGAIN;
  }

  card->mmap_info.last = (card->mmap_info.last + npages) % MAX_PAGES;
  card->mmap_info.active = 1;

  return ret;
}


/* character device mmap method */
static int nfp_mmap(struct file *filp, struct vm_area_struct *vma)
{

  return mmap_kmem(filp, vma); // Contiguous region of memory

}

/**
* @brief Char device operation and it association.
*/
static struct file_operations nfp_ops = {
  .owner      = THIS_MODULE,
  .read       = nfp_read,
  .write      = nfp_write,
  .open       = nfp_open,
  .release    = nfp_release,
  .unlocked_ioctl = nfp_ioctl,
  .compat_ioctl   = nfp_ioctl,
  .mmap       = nfp_mmap
};


/**
* @brief This function will create a new char device.
*
* @param pdev A pointer to the pci device struct.
* @param card A pointer to the main struct of the driver.
*
* @return  The possible error code.
*/
int nfpioctl_probe (struct pci_dev *pdev, struct nfp_card *card)
{
  int ret;
  ret = alloc_chrdev_region (&card->dev, 0, 1, DEVICE_NAME);
  if (ret) {
    printk (KERN_ERR "nfp: Failed to register device %s with error %d\n", DEVICE_NAME, ret);
    return ret;
  }

  card->dev_class  = class_create (THIS_MODULE, DEVICE_NAME);
  if (IS_ERR(card->dev_class)) {
    printk (KERN_ERR "nfp: Failed to create class %s with error %lld\n", DEVICE_NAME, (u64)card->dev_class);
    unregister_chrdev_region (card->dev, 1);
    return (long long)card->dev_class;
  }
  if (device_create (card->dev_class, NULL, card->dev, NULL, DEVICE_NAME) == NULL) {
    printk (KERN_ERR "nfp: Failed when creating device %s with error %d\n", DEVICE_NAME, ret);
    class_destroy (card->dev_class);
    unregister_chrdev_region (card->dev, 1);
    return -1;
  }


  cdev_init (&card->cdev, &nfp_ops);
  card->cdev.owner = THIS_MODULE;
  card->cdev.ops = &nfp_ops;
  ret = cdev_add (&card->cdev, card->dev, 1);

  if (ret) {
    printk (KERN_ERR "nfp: Failed to register device %s with error %d\n", DEVICE_NAME, ret);
    device_destroy (card->dev_class, card->dev);
    class_destroy (card->dev_class);
    unregister_chrdev_region (card->dev, 1);
    return ret;
  }

  return 0;
}

/**
* @brief Remove the char device.
*
* @param pdev A pointer to the pci device struct.
* @param card A pointer to the main struct of the device.
*
* @return The possible error code.
*/
int nfpioctl_remove (struct pci_dev *pdev, struct nfp_card *card)
{
  cdev_del (&card->cdev);
  device_destroy (card->dev_class, card->dev);
  class_destroy (card->dev_class);
  unregister_chrdev_region (card->dev, 1);
  return 0;
}
