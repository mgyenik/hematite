ENTRY(start)
SECTIONS {
  . = 0x108000;
  .text : {
    *(.text)
  }

  . = ALIGN(512);

  .bss : {
    *(.bss*);
  }
 }
