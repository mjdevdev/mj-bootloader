;remake

bits 16
org 0x7c00+512

start:
push bp
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

;switch to 32 bit mode for computations
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


; 

;mov eax, 0xffffffff
;mov [eax], 676767



;mov ah, 0x0e
;mov al, 65
;int 0x10
;mov ah, 0x0e
;mov al, 65
;int 0x10

mov [gpt_packet.start], 1
mov [gpt_packet.size], 1

push ax
mov ax, gpt_header
and ax, 0xf
mov [gpt_packet.addr], ax
mov ax, gpt_header
shr ax, 4
mov [gpt_packet.addr+2], ax
pop ax

call lba_drive_access
jc everhlt
mov si, welcome
call puts 

;switch to 1024x768




everhlt:
hlt
jmp everhlt

puts:
push si
jmp .cloop
.vloop:
mov ah,0x0e
int 0x10
add si, 1
.cloop:
mov al, [si]
or al, al

jnz .vloop
pop si
ret

lba_drive_access:
push ds
mov si, gpt_packet
and si, 0xf
mov dl, [0x7c00-2]
push ax
mov ax, gpt_packet
shr ax, 4
mov ds, ax
pop ax
mov ah, 0x42
int 0x13
pop ds
ret

align 4
gpt_packet:
db 0x10,0x0
.size resw 1
.addr resd 1
.start resq 1

welcome db "welcome ",0xd,0xa,0x0

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


gpt_header:

