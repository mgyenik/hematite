BOOTOBJS = real.o main.o

all: boot.bin

%.o: %.nasm
	nasm -felf64 -o $@ $<

%.o: %.c
	gcc -nostdinc -fno-builtin -fomit-frame-pointer -fno-stack-protector -Os -c -o $@ $<

boot.elf: $(BOOTOBJS)
	ld -N -e Main -Ttext 0x7c00 -o $@  $^

boot.bin: boot.elf
	objcopy -S -O binary -j .text $^ $@

clean:
	rm -rf *.o
	rm -rf *.out
	rm -rf boot
