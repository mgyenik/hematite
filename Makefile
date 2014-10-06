BOOTIMG = boot/boot.bin
LIBMORESTACK = /home/m/bin/lib/rustc/x86_64-unknown-linux-gnu/lib/
LIBRUST = /home/m/bin/lib/rustc/x86_64-unknown-linux-gnu/lib/
RUSTC = rustc
TARGET = test
RSRC = test.rs
OBJS = $(RSRC:.rs=.o)
QEMU = qemu-system-x86_64

RUSTFLAGS := -A dead-code
LLCFLAGS := -mattr=-fast-unaligned-mem,-vector-unaligned-mem

.PHONY: clean

all: hda.img

force:

zeros:
	dd if=/dev/zero of=zeros bs=1M count=1

$(BOOTIMG): force
	make -C boot

hda.img: $(BOOTIMG) $(TARGET).elf
	dd if=/dev/zero of=padding.bin bs=1 count=$$((1024 - $$(stat -c%s boot/boot.bin)))
	cat $(BOOTIMG) padding.bin > bootsects.bin
	cat bootsects.bin $(TARGET).elf > $@

rust:
	git submodule add https://github.com/mozilla/rust rust

libcore.rlib: rust
	$(RUSTC) rust/src/libcore/lib.rs

%.o: %.S
	gcc -c -o $@ $<

%.o: %.s
	gcc -c -o $@ $<

%.ll: %.rs
	$(RUSTC) $(RUSTFLAGS) --crate-type=lib --emit=ir -o $@ $<
	sed -i 's/ dereferenceable([0-9]\+)//g' $@
	sed -i 's/ readonly//g' $@
	sed -i 's/\(CONT_MASK.* = \)available_externally/\1internal/g' $@

%.s: %.ll
	llc-3.4 $(LLCFLAGS) -o $@ $<

$(TARGET).elf: link.ld $(OBJS)
	 $(LD) -n -o $@ -T $^

bootup: $(BOOTIMG)
	$(QEMU) -d int,cpu_reset -monitor stdio -hda hda.img

boothalt:
	$(QEMU) -S -s -hda $(BOOTIMG)

clean:
	rm -rf $(BOOTIMG)
	rm -rf bootsects
	rm -rf zeros
	rm -rf hda.img
	rm -rf *.elf
	rm -rf *.o
	rm -rf *.bin
	rm -rf *.s
	rm -rf *.ll
	make -C boot clean
