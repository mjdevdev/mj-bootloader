bits 16

global _start
;extern lol
global puts
global puts_32

global enter_protected_mode
global exit_protected_mode

extern main
;transition to 32 bit mode then drop down to 16 bit unreal mode when doing graphics

section .text
_start:
mov ax, 0
mov ds, ax
mov es, ax
mov ss, ax
mov gs, ax
mov fs, ax

xor esp, esp
mov sp, 0x7c00 

;transfer control to c???
jmp dword main

;mov di, debug
sub esp, 4
mov DWORD [esp], debug
call dword puts
add esp,4
 
jmp dword main

;call dword lol





halt:
hlt
jmp halt


;itanium i386 abi (32 bit for gcc)
puts: ;hacky function for C since gcc uses 32 bit override in 16 bit for their internals
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

puts_32: ;hacky function for C since gcc uses 32 bit override in 16 bit for their internals
bits 32 ;just with prefix lol
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

;use call this snippet will handle
;should be executing in 16 bit mode prior
;itanium i386 abi (32 bit for gcc interop)
;must supply a return address (avoid ambigutations between calling inside same asm snippet vs calling in c with 0 autonomy)
;extern "C" void enter_protected_mode(void (*ret:uint32_t)())
;input: 32 bit mode
;output:16 bit mode
;
;
enter_protected_mode:
xor ax, ax
mov ds, ax
mov ss, ax
mov es, ax
mov gs, ax
mov fs, ax

cli

lgdt [PEGDT_INFO]

push eax
mov eax, cr0
or al, 1
mov cr0, eax
pop eax
jmp 0b1000:.pe

.pe:
BITS 32
mov ax, 0b10000
mov ds, ax
mov ss, ax
mov es, ax
mov gs, ax
mov fs, ax

;sti

;jmp dword [esp+4]
add esp, 4 ;ditch the return address because we will be using the argument as return
retd
;retd ;assume that the ret address is pushed to stack as first argument with itanium abi



;use call this snippet will handle the rest.
;should be executing in 32 bit mode prior
;itanium i386 also
;extern "C" void exit_protected_mode(void (*ret:uint32_t)())
;input:32 bit mode
;output:16 bit mode
;
;
exit_protected_mode: ;not unreal mode only real. will reset the limit back smm breaks unreal anyway 
bits 32

cli

lgdt [REALGDT_INFO]

jmp 0b1000:.real

.real:
bits 16
mov ax, 0b10000
mov ds, ax
mov ss, ax
mov es, ax
mov gs, ax
mov fs, ax

mov eax, cr0
and al, -2
mov cr0, eax

jmp 0x0:.flush_cs

.flush_cs:


sti
;mov bp, sp
;jmp dword [sp+4]

add esp,  4
retd



section .data
;sixseven db 67 dup (67)
debug db "DEBUG: Stage 2 bootloader successfully loaded.",0xd,0xA,0x0
PEGDT_INFO:
dw 8*3-1 ;3 entries and minus the first bit for maximum offset
dd PEGDT
PEGDT:
dq 0 
.code_desc:
dw 0xffff
dw 0
db 0
db 0b10011011
db 0b11001111 ;full pe unlock CS, and in unreal this would be 00001111 can throw away granularity too in unreal
db 0
.data_desc:
dw 0xffff
dw 0
db 0
db 0b10010011
db 0b11001111 ;full unlock 4gb for full pe
db 0
;downgrade :wilted_rose:
REALGDT_INFO:
dw 8*3-1
dd REALGDT
REALGDT:
dq 0
.code_desc:
dw 0xffff
dw 0
db 0
db 0b10011011
db 0b00001111
db 0
.data_desc:
dw 0xffff
dw 0
db 0
db 0b10010011
db 0b00001111
db 0


