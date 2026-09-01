BITS 16
org 0x7C00+512

_start:
xor ax, ax
mov ds, ax
mov ss, ax
mov es, ax
mov fs, ax
mov gs, ax

mov sp, 0x7c00-2 ;where the drive in use number is stored

mov si, testlol
call puts




;start unreal mode transition
cli
lgdt [gdtr] ;not the value, but the pointer wrapped in a bracket like lea

or al, 1
mov cr0, eax
;32 bit unlocked. now all segment registers trigger a descriptor write to cache.

jmp 0b00001000:pemode ;load code descriptor into cs

pemode:
bits 32
;unlock all the data access registers
mov ax, 0b00010000
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax

;data access 64 bit unlocked

;disable and head out
mov eax, cr0
and eax, -2 ;ffffffffff..fff1
mov cr0, eax

;32 bit disabled. all descriptor caches are now frozen 

jmp 0x0:unrealmode ;flushes pipeline again for the remaining 32 bit mode code
;and set base to 0 limit to 0xffff






unrealmode:
bits 16

sti

xor ax, ax
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax



mov bx, 0x1234
mov eax, 0xFFFFFFFF
mov word [eax], bx  ;small snippet to verify unreal mode is enabled.

jmp hltbro ;temp end

;begin searching partition tables for windows and linux signatures
mov si, beginsearch
call puts

;do the gpt sig matching again

mov ah, 0x42
mov bp, sp
mov dl, byte [bp]
mov word [dap_gpt_packet.start], 1
mov word [dap_gpt_packet.size], 1
int 0x13

movdqu xmm0, [gpt_header]
pcmpeqq xmm0, [gpt_sig]
pmovmskb ebx, xmm0
and bx, 1

jz notgpt 

gpt:
;loop over 128 entries (possibly more and also over the 2nd gpt table) in the future





notgpt:





mov word [dap_gpt_packet.size], 33-2+1 ;mov in case gpt is matched
mov word [dap_gpt_packet.start], 2





hltbro:
hlt
jmp hltbro


puts:
cld 
lodsb
or al,al
jz .return
mov ah, 0x0e
int 0x10
jmp puts ;optimization to keep likely loops before so pipeline can recognize
;data section begins here
.return:
ret

data:
testlol db "DEBUG: Second Stage Bootloader has been successfully loaded.",0xD,0xA,0x0
beginsearch db "Searching partitions on your primary drive..",0xD,0xA,0x0

align 8
gdt_base:
dq 0x0 ;null descriptor to catch uninitialized segment registers for catching bugs; as per x86 convention, 0x0 means null means uninitialized and errors
;code descriptor
dw 0xffff
dw 0x0
db 0x0
db 0b10011011
db 0b00000000
db 0x0
;data descriptor (overlaps with code)
dw 0xffff
dw 0x0
db 0x0
db 0b10010011
db 0b10001111
db 0x0

gdtr:
dw 24-1 ;maximum possible offset (size-1)
dd gdt_base

dap_gpt_packet:
db 0x16, 0
.size dw 33-2+1
dw 0, gpt_entries_base
.start dq 2

gpt_sig:
dq 0x5452415020494645


gpt_entries_base:
gpt_header equ gpt_entries_base
resb 512*(33-2+1)


start_linux_kernel_image_load_here:
