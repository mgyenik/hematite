ENTRY(start)
SECTIONS {
  . = 0x100200;
  .text : {
    *(.text)
  }

  . = ALIGN(512);

  .bss : {
    *(.bss*);
  }
 }
