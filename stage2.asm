bits 16

global _start
;extern lol

extern main
;transition to 32 bit mode then drop down to 16 bit unreal mode when doing graphics

extern stage2_main

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
jmp dword stage2_main

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


global puts

;itanium i386 abi (32 bit for gcc)
;void puts(const char *ptr)
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


;use call this snippet will handle
;should be executing in 16 bit mode prior
;itanium i386 abi (32 bit for gcc interop)
;must supply a return address (avoid ambigutations between calling inside same asm snippet vs calling in c with 0 autonomy)
;extern "C" void enter_protected_mode(void (*ret:uint32_t)())
;input: 32 bit mode
;output:16 bit mode
;
;

global enter_protected_mode
enter_protected_mode:
bits 16
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
add esp, 4 ;remove mandatory ret addresses and hijack the control flow
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
global exit_protected_mode
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
mov ax, 0
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov gs, ax
    mov fs, ax

sti
;mov bp, sp
;jmp dword [sp+4]

add esp,  4 ;remove mandatory ret addresses and hijack the control flow
retd

global getVBEInfo
;PE mode itanium i386 abi function
;uint_16t getVBEInfo(VesaInfoBlock *ptr:uint32_t) ;lets keep it real, within 1mb from physical addr 0 get checked yo 
;
;
;
;Return:
;AL = 4Fh if function supported
;AH = status
;00h successful
;ES:DI buffer filled
;01h failed
;---VBE v2.0---
;02h function not supported by current hardware configuration
;03h function invalid in current video mode

getVBEInfo:
mov bp, sp
mov edi, [bp+4]
push edi
and edi, 0xfff00000
jnz .ptr_too_huge

pop edi

push esi
push edi
push es
mov esi, edi
shr esi, 4
mov es, si
and edi, 0b1111
mov ax, 0x4f00
int 0x10
pop es
pop edi
pop esi


retd

.ptr_too_huge:
pop edi
mov eax, 6767
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


