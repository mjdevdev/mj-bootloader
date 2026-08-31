; second stage partition type c06cda0d-65b5-49c7-a954-54594723c555
BITS 16 ; as it boots in real mode

second_boot_min equ 29 ;sectors ;version 1.0 demands 14kb for second stage (very low cost-efficiency)
base_read equ 0x7E00

org 0X7c00

;before here is the stack it grows downwards (stack starting at 7bff all the way to zero)


_start:
;mov byte [idiot], dl
;mov si, idiot
;call puts
;mov cx, dx;just save it at cx


mov ax, 0

;keep the segment selectors 0 because we dont want any implicit offsets when dealing with instructions
;to keep it real for real mode
mov ds, ax
mov ss, ax
mov es, ax
mov fs, ax
mov gs, ax
;mov cs, ax  lol can only change with jump instructions

mov sp, 0x7c00 ;growing downwards 

push dx ;save drive number that is used to boot the machine

;enable SSE 2
mov eax, cr4            
or eax, 0b000000000000000000000011000000000   
mov cr4, eax            



;load stage2 bootloader, should only be 1 bios interrupt

;verify LBA is supported. if not print a message on the terminal and hlt
mov ah, 0x41
mov bx, 0x55AA
mov dl, 0x80
int 0x13
cmp bx, 0xAA55
jnz error_edd

;verify whether drive is mbr or gpt. if gpt then the bootloader will be stored at 34. still no guarantees though. 
;but at least there should be a space huge enough to accomodate the bootloader, like 34-62 at least


mov si, dap_signature
call lba_drive_call
jc error_unknown_or_annoying


mov cx, 2
mov si, base_read ;immediately at the signature (first byte of partition table in guid assuming it is)
mov di, guidsig
repe cmpsd
jnz not_gpt


;found to be matching guid signature, now scan for the mj-bootloader partition that stores the second stage bootloader
;only supports searching 128 entries and 1 partition table for now

mov si, dap_guid_table
call lba_drive_call
jc error_unknown_or_annoying

mov si, base_read
mov cx, 128


;save sse (dont need to save because i am not calling any bios interrupts in between..?
;sub sp, 16 ;unaligned access please
;mov bp, sp
;movdqu [bp], xmm0
;sub sp, 16
;mov bp, sp
;movdqu [bp], xmm1

;initializations
movdqu xmm0, [mjpartid]
mov cx, 128

.loop_find_mj_partition:
movdqu xmm1, [si] ;fetch first 128 bits
pcmpeqb xmm1, xmm0
pmovmskb edi, xmm1
not di
test di, di
jz .found


add si, 128 
sub cx, 1
;only add 127 times, 128th is ditched because out of bound
jnz .loop_find_mj_partition 
;notfound (fall through)

jmp error_2nd_stage_copy

;put vars here

.found: 
;mov bpl, [si+32]
;movdqu xmm2, [one]
;movdqu xmm0, [si+32]
movdqu xmm1, [si+40]
psubq xmm1, [si+32]
paddq xmm1, [one]
psubq xmm1, [sixtytwo] 
psrlq xmm1, 63
pand xmm1, [one] ;extract the LSB as the result
movdqu [one], xmm1
mov bl, [one] ;get the bit in the register and test it
test bl, bl
jnz error_2nd_stage_copy ;too small of a partition. need to extend.

;reset 1
mov [one], 1
movdqu xmm0, [si+32]
mov bx, 62

;now copy the part 2 to the base read
jmp copy_2nd_stage



not_gpt:
movdqu xmm0, [one]
mov bx, 62
copy_2nd_stage:
;load second stage bootloader after the 512 byte mark (since partition table will be mapped too because bios fetch 512 bytes every time)
;setup correct starting sector and sector count
mov si, dap_second_stage
movdqu [si+8], xmm0
mov WORD [si+2], bx ;NOT the actual lba sectors, version 1 is 62 sectors exactly, totaling 31ish kbs
call lba_drive_call
jc error_2nd_stage_copy


mov ax, base_read
jmp 0x0000:base_read
jmp ax ;run second stage bootlaoder





jmp infinite_halt

;db "FUCKYOU"

error_edd:
mov si, notsupport
jmp error_stub

error_2nd_stage_copy:
mov si, no2nd
jmp error_stub

error_unknown_or_annoying:
mov si, unknown

error_stub:
call puts
jmp infinite_halt

infinite_halt:
hlt ;sleep, wait for any interrupts..?
jmp infinite_halt

lba_drive_call: ;has to be top level calls, or else ret addresses pollute it
mov ah, 0x42
mov bx, sp
add bx, 2
mov dl, byte [bx]
;mov dx, cx
;mov dx, 0x80
int 0x13
ret


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
helloworld db "h",0x0
notsupport db "Drive too old.",0xD,0xA,0x0
no2nd db "Drive smol or broken.", 0xD, 0xA, 0x0
unknown db "IDK HD Error.",0xD,0xA,0x0
guidsig dq 0x5452415020494645 
; c06cda0d-65b5-49c7-a954-54594723c555
mjpartid dd BYTE %(0x0d,0xda,0x6c,0xc0)
dw BYTE %(0xb5,0x65)
dw BYTE %(0xc7,0x49)
dw 0x54a9
dd 0x23475954      
dw 0x55c5
align 16
one dq 0x1
align 16
sixtytwo dq 62
;len equ $-$$ ;useless because it is not ret and requires multiple lines

align 4

dap_second_stage: ;obsolete
;disk address packet (standard EDD)
db 0x10
db 0x0
dw 62 ;ALWAYS 62 , count
dw base_read 
dw 0
dd 0 ;TO BE SET LATER, start
dd 0

dap_signature:
;disk address packet (standard EDD)
db 0x10
db 0x0
dw 1
dw base_read
dw 0
dd 1
dd 0

dap_guid_table:
;disk address packet (standard EDD)
db 0x10
db 0x0
dw 33-2+1
dw base_read
dw 0
dd 2
dd 0

%assign binsize $-_start

%if binsize > 446
    %error "The bootloader code has exceeded 446 (size" %+ %!string binsize %+ " ), the maximum number allowed for mbr bootloaders!"
%else

%endif

times 446-($-$$) db 0 ;bytes allocated for bootloader under mbr scheme, and protective mbr under gpt
times 510-446 db 0 ;this part is not copied if installing bootloader ;remainder of the mbr record
dw 0xAA55

