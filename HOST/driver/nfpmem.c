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
* @brief This module implements the registration of the char device and the IOCTL handle routine.
* @author José Fernando Zazo Rollón, josefernando.zazo@estudiante.uam.es
* @date 2013-07-05
*/

#include "nfpmem.h"
#include <linux/pagemap.h>
#include <linux/sched.h>
#include <linux/fs_struct.h>
#include <linux/hugetlb.h>
#include <linux/version.h>


static int        num_pages = 0;    /**< Number of 4KB pages in the HP file system */
static struct page **pages  = NULL; /**< Struct pages associated to the buffer in use */



/**
* @brief This function maps the user memory pointed by di into kernel space.
* A list of pointer to pages is returned by the ppag argument.
*
* @param db User data that is necessary to map.
* @param card Driver main structure.
* @param ppag ppag will point to a list of pointer of pages it the invocation
* was successful.
*
* @return The number of pointer of pages in *ppag.
*/
static int getUserHugePages (struct dma_buffer *db, struct nfp_card *card, struct page ***ppag)
{
  int ret;
  /*Assuming the userspace pointer is passed as an unsigned long, */
  /*calculate the first,last, and number of pages being transferred via*/
  u64 udata  = (u64) db->data;
  u64 nbytes = db->length;
  u64 first_page = (udata & PAGE_MASK) >> PAGE_SHIFT;
  u64 last_page = ( (udata + nbytes - 1) & PAGE_MASK) >> PAGE_SHIFT;
  u64 npages = last_page - first_page + 1;
  struct page **pag;
  u64 num_huge_pages = 0;
  u64 acum;
  int i;
  pag = vmalloc (npages * sizeof (struct page *));
  if (pag == NULL) {
    return -EFAULT;
  }

  *ppag = pag;
  /* Ensure that all userspace pages are locked in memory for the */
  /* duration of the DMA transfer */
  down_read (&current->mm->mmap_sem);
  #if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 6, 0)
    /*
    long get_user_pages(unsigned long start, unsigned long nr_pages,
          unsigned int gup_flags, struct page **pages,
          struct vm_area_struct **vmas); */
    ret = get_user_pages(udata, npages, FOLL_WRITE, pag, NULL);
  #else
    /*
    long get_user_pages(struct task_struct *tsk, struct mm_struct *mm,
        unsigned long start, unsigned long nr_pages,
        int write, int force, struct page **pages,
        struct vm_area_struct **vmas); */
    ret = get_user_pages (current,
                        current->mm,
                        udata,
                        npages,
                        1,         /* We can write in this region */
                        0,         /* Force */
                        pag,
                        NULL);

  #endif
  up_read (&current->mm->mmap_sem);

  num_huge_pages = db->length;
  num_huge_pages /= db->hp_size;
  acum = db->hp_size;
  acum *= num_huge_pages;

  if (acum != db->length) {
    num_huge_pages++;
  }

  for (i = 0; i < num_huge_pages; i++) {
    card->buffer.page_address[i] = (u64) page_address (pag[db->hp_size / PAGE_SIZE * i]);
  }

  card->buffer.npages = num_huge_pages;
  card->buffer.virtual = (void *)db->data;
  card->buffer.length =  db->length;

  return ret;
}


/**
* @brief Release an user previously registered buffer.
*
* @param pages The content of the ppag argument returned by getUserPages function.
* @param num_pages The number of total pages pointed by pages.
*/
static void forgetUserHugePages (struct page **pages, int num_pages)
{
  int i;

  for (i = 0; i < num_pages; i++) {
    down_read (&current->mm->mmap_sem);

    if (!PageReserved (pages[i])) {
      SetPageDirty (pages[i]);
      #if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 6, 0)
        put_page (pages[i]);
      #else
        page_cache_release (pages[i]);
      #endif
    } else {
      #if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 6, 0)
        put_page (pages[i]);
      #else
        page_cache_release (pages[i]);
      #endif
    }

    up_read (&current->mm->mmap_sem);
  }

  vfree (pages);
}


int reg_hugemem(struct nfp_card *card, struct dma_buffer *db)
{
  if ( (num_pages = getUserHugePages (db, card, &pages)) < 0) {        // Map user memory into kernel space
    card->buffer.length  = 0;
    up (&card->sem_op);
    printk (KERN_ERR "nfp: user memory cant be mapped\n");
    return -EFAULT;
  } else {
    card->buffer.virtual = db->data;
    card->buffer.length  = db->length;
    card->buffer.page_size  = db->hp_size;
  }

  return 0;
}

int unreg_hugemem (struct nfp_card *card)
{
  if (card->buffer.length) { /* Ensure the operation is executed just one time. */
    card->buffer.length = 0;
    forgetUserHugePages (pages, num_pages);
    num_pages = 0;
  }

  return 0;
}
