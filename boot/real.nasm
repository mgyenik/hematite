%define FREE_SPACE      0x9000 ; Used for Identity mapping page table
%define E820_SPACE      0x8000 ; Used for E820 memory detection table
%define PAGE_PRESENT    (1 << 0)
%define PAGE_WRITE      (1 << 1)
 
%define CODE_SEG    0x0008
%define DATA_SEG    0x0010

SECTION .text
BITS 16
 
; Main entry point where BIOS leaves us.
 
Main:
    jmp 0x0000:.FlushCS               ; Some BIOS' may load us at 0x0000:0x7C00 while other may load us at 0x07C0:0x0000.
                                      ; Do a far jump to fix this issue, and reload CS to 0x0000.
.FlushCS:   
    xor ax, ax
 
    ; Set up segment registers.
    mov ss, ax
    ; Set up stack so that it starts below Main.
    mov sp, Main
 
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    cld
 
    ; Detect memory for Rust code
    mov edi, E820_SPACE + 4
    call do_e820

    ; Point edi to a free space bracket.
    mov edi, FREE_SPACE
    ; Switch to Long Mode.
    jmp SwitchToLongMode
 
; use the INT 0x15, eax= 0xE820 BIOS function to get a memory map
; inputs: es:di -> destination buffer for 24 byte entries
; outputs: bp = entry count, trashes all registers except esi
do_e820:
    xor ebx, ebx        ; ebx must be 0 to start
    xor bp, bp      ; keep an entry count in bp
    mov edx, 0x0534D4150    ; Place "SMAP" into edx
    mov eax, 0xe820
    mov [es:di + 20], dword 1   ; force a valid ACPI 3.X entry
    mov ecx, 24     ; ask for 24 bytes
    int 0x15
    jc short .failed    ; carry set on first call means "unsupported function"
    mov edx, 0x0534D4150    ; Some BIOSes apparently trash this register?
    cmp eax, edx        ; on success, eax must have been reset to "SMAP"
    jne short .failed
    test ebx, ebx       ; ebx = 0 implies list is only 1 entry long (worthless)
    je short .failed
    jmp short .jmpin
.e820lp:
    mov eax, 0xe820     ; eax, ecx get trashed on every int 0x15 call
    mov [es:di + 20], dword 1   ; force a valid ACPI 3.X entry
    mov ecx, 24     ; ask for 24 bytes again
    int 0x15
    jc short .e820f     ; carry set means "end of list already reached"
    mov edx, 0x0534D4150    ; repair potentially trashed register
.jmpin:
    jcxz .skipent       ; skip any 0 length entries
    cmp cl, 20      ; got a 24 byte ACPI 3.X response?
    jbe short .notext
    test byte [es:di + 20], 1   ; if so: is the "ignore this data" bit clear?
    je short .skipent
.notext:
    mov ecx, [es:di + 8]    ; get lower dword of memory region length
    or ecx, [es:di + 12]    ; "or" it with upper dword to test for zero
    jz .skipent     ; if length qword is 0, skip entry
    inc bp          ; got a good entry: ++count, move to next storage spot
    add di, 24
.skipent:
    test ebx, ebx       ; if ebx resets to 0, list is complete
    jne short .e820lp
.e820f:
    mov [E820_SPACE], bp  ; store the entry count
    clc         ; there is "jc" on end of list to this point, so the carry must be cleared
    ret
.failed:
    stc         ; "function unsupported" error exit
    ret

; Function to switch directly to long mode from real mode.
; Identity maps the first 2MiB.
; Uses Intel syntax.
 
; es:edi    Should point to a valid page-aligned 16KiB buffer, for the PML4, PDPT, PD and a PT.
; ss:esp    Should point to memory that can be used as a small (1 dword ) stack
 
SwitchToLongMode:
    ; Zero out the 16KiB buffer.
    ; Since we are doing a rep stosd, count should be bytes/4.   
    push di                           ; REP STOSD alters DI.
    mov ecx, 0x1000
    xor eax, eax
    cld
    rep stosd
    pop di                            ; Get DI back.
 
 
    ; Build the Page Map Level 4.
    ; es:di points to the Page Map Level 4 table.
    lea eax, [es:di + 0x1000]         ; Put the address of the Page Directory Pointer Table in to EAX.
    or eax, PAGE_PRESENT | PAGE_WRITE ; Or EAX with the flags - present flag, writable flag.
    mov [es:di], eax                  ; Store the value of EAX as the first PML4E.
 
 
    ; Build the Page Directory Pointer Table.
    lea eax, [es:di + 0x2000]         ; Put the address of the Page Directory in to EAX.
    or eax, PAGE_PRESENT | PAGE_WRITE ; Or EAX with the flags - present flag, writable flag.
    mov [es:di + 0x1000], eax         ; Store the value of EAX as the first PDPTE.
 
 
    ; Build the Page Directory.
    lea eax, [es:di + 0x3000]         ; Put the address of the Page Table in to EAX.
    or eax, PAGE_PRESENT | PAGE_WRITE ; Or EAX with the flags - present flag, writeable flag.
    mov [es:di + 0x2000], eax         ; Store to value of EAX as the first PDE.
 
 
    push di                           ; Save DI for the time being.
    lea di, [di + 0x3000]             ; Point DI to the page table.
    mov eax, PAGE_PRESENT | PAGE_WRITE    ; Move the flags into EAX - and point it to 0x0000.
 
 
    ; Build the Page Table.
.LoopPageTable:
    mov [es:di], eax
    add eax, 0x1000
    add di, 8
    cmp eax, 0x200000                 ; If we did all 2MiB, end.
    jb .LoopPageTable
 
    pop di                            ; Restore DI.
 
    ; Disable IRQs
    mov al, 0xFF                      ; Out 0xFF to 0xA1 and 0x21 to disable all IRQs.
    out 0xA1, al
    out 0x21, al
 
    nop
    nop
 
    lidt [IDT]                        ; Load a zero length IDT so that any NMI causes a triple fault.
 
    ; Enter long mode.
    mov eax, 10100000b                ; Set the PAE and PGE bit.
    mov cr4, eax
 
    mov edx, edi                      ; Point CR3 at the PML4.
    mov cr3, edx
 
    mov ecx, 0xC0000080               ; Read from the EFER MSR. 
    rdmsr    
 
    or eax, 0x00000100                ; Set the LME bit.
    wrmsr
 
    mov ebx, cr0                      ; Activate long mode -
    or ebx,0x80000001                 ; - by enabling paging and protection simultaneously.
    mov cr0, ebx                    
 
    lgdt [GDT.Pointer]                ; Load GDT.Pointer defined below.
 
    jmp CODE_SEG:LongMode             ; Load CS with 64 bit segment and flush the instruction cache
 
 
    ; Global Descriptor Table
GDT:
.Null:
    dq 0x0000000000000000             ; Null Descriptor - should be present.
 
.Code:
    dq 0x0020980000000000             ; 64-bit code descriptor. 
    dq 0x0000900000000000             ; 64-bit data descriptor. 
 
ALIGN 4
    dw 0                              ; Padding to make the "address of the GDT" field aligned on a 4-byte boundary
 
.Pointer:
    dw $ - GDT - 1                    ; 16-bit Size (Limit) of GDT.
    dd GDT                            ; 32-bit Base Address of GDT. (CPU will zero extend to 64-bit)
 
ALIGN 4
IDT:
    .Length       dw 0
    .Base         dd 0
 
 
[BITS 64]
;=============================================================================
; ATA PIO reader taken from OS Dev Wiki
; ATA read sectors (CHS mode) 
; Max head index is 15, giving 16 possible heads
; Max cylinder index can be a very large number (up to 65535)
; Sector is usually always 1-63, sector 0 reserved, max 255 sectors/track
; If using 63 sectors/track, max disk size = 31.5GB
; If using 255 sectors/track, max disk size = 127.5GB
; See OSDev forum links in bottom of [http://wiki.osdev.org/ATA]
;
; @param EBX The CHS values; 2 bytes, 1 byte (BH), 1 byte (BL) accordingly
; @param CH The number of sectors to read
; @param RDI The address of buffer to put data obtained from disk               
;
; @return None
;=============================================================================
ata_chs_read:   pushfq
                push rax
                push rbx
                push rcx
                push rdx
                push rdi
 
                mov rdx,1f6h            ;port to send drive & head numbers
                mov al,bh               ;head index in BH
                and al,00001111b        ;head is only 4 bits long
                or  al,10100000b        ;default 1010b in high nibble
                out dx,al
 
                mov rdx,1f2h            ;Sector count port
                mov al,ch               ;Read CH sectors
                out dx,al
 
                mov rdx,1f3h            ;Sector number port
                mov al,bl               ;BL is sector index
                out dx,al
 
                mov rdx,1f4h            ;Cylinder low port
                mov eax,ebx             ;byte 2 in ebx, just above BH
                mov cl,16
                shr eax,cl              ;shift down to AL
                out dx,al
 
                mov rdx,1f5h            ;Cylinder high port
                mov eax,ebx             ;byte 3 in ebx, just above byte 2
                mov cl,24
                shr eax,cl              ;shift down to AL
                out dx,al
 
                mov rdx,1f7h            ;Command port
                mov al,20h              ;Read with retry.
                out dx,al

                in al, dx               ; Ghetto 400ns delay
                in al, dx
                in al, dx
                in al, dx
                in al, dx
                in al, dx
                in al, dx
                in al, dx
 
.still_going:   in al,dx
                test al,8               ;the sector buffer requires servicing.
                jz .still_going         ;until the sector buffer is ready.
 
                mov rax,512/2           ;to read 256 words = 1 sector
                xor bx,bx
                mov bl,ch               ;read CH sectors
                mul bx
                mov rcx,rax             ;RCX is counter for INSW
                mov rdx,1f0h            ;Data port, in and out
                rep insw                ;in to [RDI]
 
                pop rdi
                pop rdx
                pop rcx
                pop rbx
                pop rax
                popfq
                ret

LongMode:
extern bootmain
Longmain:
    ; Load 2048 bytes of secondary bootcode
    mov ebx, 0x0002 ; Second sector
    mov ch, 1       ; Read 1 sector
    mov rdi, 0x7e00 ; Address of buffer
    call ata_chs_read ; Call function stolen from OSDev Wiki
    jmp bootmain                     ; You should replace this jump to wherever you want to jump to.
 
; Pad out file.
times 510 - ($-$$) db 0
dw 0xAA55 ; BIOS magic! last 2 bytes of sector must be this
