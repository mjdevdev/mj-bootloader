;remake

bits 16
org 0x7c00+512

start:
xor ax, ax
mov ds, ax
mov ss, ax
mov fs, ax
mov gs, ax
mov es, ax


cli

lgdt [gdt_desc]

mov eax, cr0
or al, 1
mov cr0, eax

jmp 0b10000:pe

pe:


mov bx, 0b1000
mov ds, bx
;mov ss, bx ;safe since it only decides wrap behaviour 
mov es, bx
mov gs, bx
mov fs, bx 

and eax, -2
mov cr0, eax


jmp 0x0:unreal_mode

unreal_mode:
sti
mov ax, 0
mov ds, ax
mov es, ax
mov gs, ax
mov fs, ax

;mov eax, 0xffffffff
;mov [eax], 676767



;mov ah, 0x0e
;mov al, 65
;int 0x10
;mov ah, 0x0e
;mov al, 65
;int 0x10

everhlt:
hlt
jmp everhlt

gdt_desc:
dw 23
dd gdt_base

gdt_base:
dq 0
datadesc:
dw 0xffff 
dw 0 
db 0
db 0b10010011
db 0b11001111
db 0
codedesc:
dw 0xffff
dw 0
db 0
db 0b10011011
db 0b00001111 ; no point setting granularity.. it will execute in implicit 16 bit encoding or else bios crashes
db 0
