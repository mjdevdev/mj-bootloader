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



mov eax, cr0
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





;begin searching partition tables for windows and linux signatures
mov si, beginsearch
call puts

;do the gpt sig matching again

mov si, dap_gpt_packet

mov word [dap_gpt_packet.start], 1
mov word [dap_gpt_packet.addr], gpt_header
mov word [dap_gpt_packet.addr+2], 0
mov word [dap_gpt_packet.size], 1
call lba_drive_call
jc error_pa_copy


;another way to compare the gpt header
movq xmm0, [gpt_header]
pcmpeqq xmm0, [gpt_sig]
pmovmskb ebx, xmm0
and bx, 1 ;only get the first 8 bytes compare result 

jz handle_bios

movgptwholearray: ;0xff max entries, 0xff max single entry size, for gpt
;loop over partition table again

movq mm0,[gpt_header+0x48]
movq [dap_gpt_packet.start], mm0 ;address starts at start LBA of array
mov eax, [gpt_header+0x50] ; eax = number of entries
push eax ;save the number of entries
and eax, 0xffff ;hard cap at 65535 entires dont need that much
mov ebx, [gpt_header+0x54]
and ebx, 0xffff; sorry, capping single entry size at 65535 bytes too
push ebx ;save single tnry size
imul eax, ebx ; multiplied by the size of single entry
cmp eax, 492032-512*62 ;limit of total size array 
ja error_phuge


;pop ebx #single entry size
;pop eax #num of entries in primary/secondary gpt



xor edx, edx ;upper 32 bits zero out
mov ebx, 512 ;divide by sectors
div ebx
or edx, edx
jz no_remainder
add eax, 1

no_remainder:
mov [dap_gpt_packet.size], ax
mov word [dap_gpt_packet.addr], gpt_entries_base
mov word [dap_gpt_packet.addr+2], 0
mov si, dap_gpt_packet
call lba_drive_call
jc error_pa_copy


jmp handle_gpt


;read the first partitions array

;xor ax, ax ;pages (page variable in menu)

;ebx at topmost stack 
;mov bp, sp
;mov cx, [bp] ;single entry size: it truncates because pushed ebx and eax capped at max word 65535
;mov bp, sp
;add bp, 4 ;
;mov dx, [bp] ;num entries single arr



;ax page
;bx num entries (counter)
;dx single entry size

handle_bios: ;display fixed 4 entries for boot, easy job
;set up down/left right, numpads interrupt




;gui routines somewhere here





;user chooses one entry here with interrupt key
;then iret jump back here


jmp hltbro


;ax page
;bx num entries (counter)
;dx single entry size
handle_gpt:

;set up down/left right, numpads interrupt
xor eax, eax
xor edx, edx
xor ebx, ebx
xor ecx, ecx
xor eax, eax ;starts from 0 
mov bp, sp
mov edx, [bp] ;single entry size
mov bp, sp
add bp, 4
mov ebx, [bp] ;num entries single array

load_entries_page:
mov ecx, 10 ;10 entries per page to show (max)
mov bp, gpt_entries_base ;read ptr read from entries
imul ecx, eax 
add bp, cx

mov di, gpt_entries_temp ;write ptr write to temp storage for 10 entries


mov ecx, 10

.loop_put:
push ecx
mov ecx, edx ;cx becomes the single entry size
.loop_copy:
movdqu xmm0, [bp]
movdqu [di], xmm0
add di, 16
add bp, 16
sub ecx, 16 ;use xmm to load memory 
jge .loop_copy

add ecx, 16 ;handle the remainder (leftover data not factor of 16)
sub di, 16 ;write ptr is 1 xmm past last written
sub bp, 16 ;read ptr too

push eax
push edx
push ebx
push esi

mov eax, edx ;ax now contains the single page size and divide it by 16 later
xor edx, edx
mov bx, 16
idiv bx

or edx, edx
jz .has_remainder_after

;deal with remainder (that falls out of 16) because of new gpt updates

;use cx for rep movsb
mov cx, dx ;move the remainder to the counter
mov si, bp;the read ptr 
;mov di, di ;di si already di
rep movsb

pop esi
pop ebx
pop edx
pop eax
.has_remainder_after:

pop ecx ;recover page size counter
sub ecx, 1
jnz .loop_put

;finish loading entries, now print the entries using VESA (or GOP if this is uefi mode)



jmp hltbro

error_pa_copy:
mov si, cannot_copy_pa
call puts
jmp hltbro


error_phuge:
mov si, partition_table_too_huge
call puts

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


lba_drive_call: ;has to be top level calls, or else ret addresses pollute it
mov ah, 0x42
mov bx, 0x7c00-2
xor dx, dx
mov dl, byte [bx]
;mov dx, cx
;mov dx, 0x80
int 0x13
ret

data:
testlol db "DEBUG: Second Stage Bootloader has been successfully loaded.",0xD,0xA,0x0
beginsearch db "Searching partitions on your primary drive..",0xD,0xA,0x0
partition_table_too_huge db "ERROR: GPT Partition is too huge, must not exceed 460 KiB!",0xd,0xa,0x0
cannot_copy_pa db "ERROR: Cannot copy GPT primary GPT for some reasons.",0XD,0XA,0x0
itworks db "It works ", 0xd,0xa,0x0

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
.addr resd 1 
.start dq 2

align 16
gpt_sig:
dq 0x5452415020494645

disk_header: 
resb 512



gpt_header: ;also houses the header
gpt_entries_base equ gpt_header+512
resb 492032-512*62  ; 480.5 KiB (max safe contiguous space after bootloaders)

gpt_entries_temp: ;for holding loaded entries of the current page

;start_linux_kernel_image_load_here: ;no, we read bios/uefi memory layout then
;decide the biggest memory region


