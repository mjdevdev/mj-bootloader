bits 16

global _start
extern lol
global puts
;transition to 32 bit mode then drop down to 16 bit unreal mode when doing graphics

section .text
_start:
mov ax, 0
mov ds, ax
mov es, ax
mov ss, ax
mov gs, ax
mov fs, ax

xor sp, sp
mov sp, 0x7c00 

;mov di, debug
sub esp, 4
mov DWORD [esp], debug
call dword puts
add esp,4
call dword lol

halt:
hlt
jmp halt


puts:
mov edi, [esp+4]
jmp .loop
.cloop:
mov ah, 0x0e
int 0x10
inc edi
.loop:
mov al, [edi]
or al, al
jnz .cloop
retd



section .data
sixseven db 67 dup (67)
debug db "DEBUG: Stage 2 bootloader successfully loaded.",0xd,0xA,0x0
