#include "elf.h"

/**********************************************************************
 * This is taken from MIT's JOS, modified slightly, and will be used until I have
 * a better boot process....
 *
 * This a dirt simple boot loader, whose sole job is to boot
 * an ELF kernel image from the first IDE hard disk.
 **********************************************************************/

#define SECTSIZE	512
#define ELFHDR		((struct Elf *) 0x100000) // scratch space, 1MiB of space mapped

void readsect(void*, uint32_t);
void readseg(uint64_t, uint64_t, uint64_t, int);

static __inline uint8_t
inb(int port)
{
    uint8_t data;
    __asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
    return data;
}

static __inline void
insl(int port, void *addr, int cnt)
{
    __asm __volatile("cld\n\trepne\n\tinsl"         :
             "=D" (addr), "=c" (cnt)        :
             "d" (port), "0" (addr), "1" (cnt)  :
             "memory", "cc");
}

static __inline void
outb(int port, uint8_t data)
{
    __asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
}

static __inline void
outw(int port, uint16_t data)
{
    __asm __volatile("outw %0,%w1" : : "a" (data), "d" (port));
}

/* Primitive debugging method */
void printx(char *mem, int len, int line)
{
    int i;
    volatile unsigned short *vga_mem;

    vga_mem = (volatile unsigned short *)0xB8000;
    vga_mem += 80*line;

    for (i = 0; i < len; i++) {
        unsigned char hex;

        /* First nibble */
        hex = (mem[i] >> 4) & 0xf;
        if (hex < 10)
            hex += 0x30;
        else
            hex += 55;

        *vga_mem++ = 0x0200 | (unsigned short)hex;

        /* Second nibble */
        hex = mem[i] & 0xf;
        if (hex < 10)
            hex += 0x30;
        else
            hex += 55;

        *vga_mem++ = 0x0200 | (unsigned short)hex;
    }
}

void memset(void *p, uint8_t value, uint32_t size) {
    uint8_t *end = (uint8_t *) ((uintptr_t) p + size);

    while ( (uint8_t*) p < end ) {
        *((uint8_t*)p) = value;
        p++;
    }
}

void
bootmain(void)
{
	struct Proghdr *ph, *eph;
    char c = 0xcc;
    int i = 2;

	// read 1st page off disk
    printx(&c, 1, 0);
	readseg((uint64_t) ELFHDR, SECTSIZE*8, 0, 1);

	// is this a valid ELF?
	if (ELFHDR->e_magic != ELF_MAGIC) {
        printx(&ELFHDR->e_magic, 4, 1);
		goto bad;
    }

	// load each program segment (ignores ph flags)
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	for (; ph < eph; ph++) {
        if (ph->p_type == 1) { // PT_LOAD
            // p_pa is the load address of this segment (as well
            // as the physical address)
            readseg(ph->p_pa, ph->p_filesz, ph->p_offset, i);
            // Zero memory at end of load (.bss)
            memset(ph->p_pa + ph->p_filesz, 0, ph->p_memsz - ph->p_filesz);
        }

        i += 2;
    }

	// call the entry point from the ELF header
	// note: does not return!
	((void (*)(void)) (ELFHDR->e_entry))();

bad:
	while (1)
		/* do nothing */;
}

// Read 'count' bytes at 'offset' from kernel into physical address 'pa'.
// Might copy more than asked
void
readseg(uint64_t pa, uint64_t count, uint64_t offset, int line)
{
	uint64_t end_pa;
    uint32_t disk_offset;

    printx(&pa, 8, line);

	end_pa = pa + count;
	
	// round down to sector boundary
	//pa &= ~(SECTSIZE - 1);

	// translate from bytes to sectors, and kernel starts at sector 2
	disk_offset = (offset / SECTSIZE) + 2;
    //printx(&disk_offset, 4, line+1);
    pa -= offset;
    printx(&pa, 8, line+1);

	// If this is too slow, we could read lots of sectors at a time.
	// We'd write more to memory than asked, but it doesn't matter --
	// we load in increasing order.
	while (pa < end_pa) {
		// Since we haven't enabled paging yet and we're using
		// an identity segment mapping (see boot.S), we can
		// use physical addresses directly.  This won't be the
		// case once JOS enables the MMU.
		readsect((uint8_t*) pa, disk_offset);
		pa += SECTSIZE;
		disk_offset++;
	}
}

void
waitdisk(void)
{
	// wait for disk reaady
	while ((inb(0x1F7) & 0xC0) != 0x40)
		/* do nothing */;
}

void
readsect(void *dst, uint32_t offset)
{
	// wait for disk to be ready
	waitdisk();

	outb(0x1F2, 1);		// count = 1
	outb(0x1F3, offset);
	outb(0x1F4, offset >> 8);
	outb(0x1F5, offset >> 16);
	outb(0x1F6, (offset >> 24) | 0xE0);
	outb(0x1F7, 0x20);	// cmd 0x20 - read sectors

	// wait for disk to be ready
	waitdisk();

	// read a sector
	insl(0x1F0, dst, SECTSIZE/4);
}
