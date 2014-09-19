BOOTIMG = boot/boot
LIBMORESTACK = /home/m/bin/lib/rustc/x86_64-unknown-linux-gnu/lib/
LIBRUST = /home/m/bin/lib/rustc/x86_64-unknown-linux-gnu/lib/
RUSTC = rustc -Z no-landing-pads --target x86_64-unknown-linux-gnu #-L $(LIBMORESTACK) -L $(LIBRUST)
TARGET = test
RSRC = test.rs
OBJS = $(RSRC:.rs=.o)
QEMU = /home/m/git/qemu/x86_64-softmmu/qemu-system-x86_64

.PHONY: clean

all: hda.img

force:

zeros:
	dd if=/dev/zero of=zeros bs=1M count=1

$(BOOTIMG): force
	make -C boot

hda.img: $(BOOTIMG) $(TARGET).elf
	dd if=/dev/zero of=padding bs=1 count=$$((1024 - $$(stat -c%s boot/boot)))
	cat $(BOOTIMG) padding > bootsects
	cat bootsects $(TARGET).elf > $@

rust:
	git submodule add https://github.com/mozilla/rust rust

libcore.rlib: rust
	$(RUSTC) rust/src/libcore/lib.rs

%.o: %.S
	gcc -c -o $@ $<

%.o: %.rs
	$(RUSTC) --crate-type=lib --emit=obj -o $@ $<
	#$(RUSTC) -o $@ $<

$(TARGET).elf: link.ld $(OBJS)
	 $(LD) -n -o $@ -T $^ "-(" libcore.rlib "-)"

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
	make -C boot clean
