ORG 0x7c00                ; add to offsets

start:
   xor ax, ax             ; make it zero
   mov ds, ax             ; DS=0
   mov ss, ax             ; stack starts at seg 0
   mov sp, 0x9c00         ; 2000h past code start, 
                          ; making the stack 7.5k in size

   cli                    ; no interrupts
   push ds                ; save real mode

   lgdt [gdtinfo]         ; load gdt register

   mov  eax, cr0          ; switch to pmode by
   or al,1                ; set pmode bit
   mov  cr0, eax
   jmp 0x8:pmode

pmode:
   mov  bx, 0x10          ; select descriptor 2
   mov  ds, bx            ; 10h = 10000b

   and al,0xFE            ; back to realmode
   mov  cr0, eax          ; by toggling bit again
   jmp 0x0:unreal

unreal:
   pop ds                 ; get back old segment
   sti

   mov bx, 0x0f01         ; attrib/char of smiley
   mov eax, 0x0b0fffffff      ; note 32 bit offset
   mov word [ds:eax], bx

   mov ah, 0x0e
   mov al, 65
   int 0x10

   jmp $                  ; loop forever

gdtinfo:
   dw gdt_end - gdt - 1   ;last byte in table
   dd gdt                 ;start of table

gdt:        dd 0,0        ; entry 0 is always unused
codedesc:   db 0xff, 0xff, 0, 0, 0, 10011010b, 00000000b, 0
flatdesc:   db 0xff, 0xff, 0, 0, 0, 10010010b, 11001111b, 0
gdt_end:

   times 510-($-$$) db 0  ; fill sector w/ 0's
   dw 0xAA55              ; Required by some BIOSes

