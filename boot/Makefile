BOOTOBJS = real.o main.o

all: boot

%.o: %.nasm
	nasm -felf64 -o $@ $<

%.o: %.c
	gcc -nostdinc -fno-builtin -fomit-frame-pointer -fno-stack-protector -Os -c -o $@ $<

boot: $(BOOTOBJS)
	ld -N -e Main -Ttext 0x7c00 -o $@.out  $^
	objcopy -S -O binary -j .text $@.out $@

clean:
	rm -rf *.o
	rm -rf *.out
	rm -rf boot
