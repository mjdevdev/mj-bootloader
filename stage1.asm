; second stage partition type c06cda0d-65b5-49c7-a954-54594723c555
BITS 16 ; as it boots in real mode

second_boot_min equ 29 ; sectors
base_read equ 0x7E00

org 0X7c00

_start:
    xor ax, ax                      ; clear ax

    mov ds, ax
    mov ss, ax
    mov es, ax
    mov gs, ax                      ; initialize GS

    mov sp, 0x7c00                  ; stack grows downwards
    push dx 
    mov bp, dx                      ; preserve boot drive number in BP

    ; enable SSE2
    mov eax, cr4     
    or ah, 6     
    mov cr4, eax     

    ; Read LBA 1 (GPT Header)
    mov si, dap_signature
    mov byte [dap_signature+2], 1
    mov dword [dap_signature+8], 1
    mov dword [dap_signature+12], 0
    call lba_drive_call
    jc error_unknown_or_annoying

    ; Check GPT UUID signature in 1st sector (decide if gpt or not
    mov cx, 2
    mov si, base_read
    mov di, guidsig
    repe cmpsd
    jnz not_gpt

    mov si, dap_guid_table

    ;cld
    ;xor eax, eax
    ;mov di, base_read+0x48+2        ; point to upper 6 bytes of PartitionEntryLBA
    ;scasw
    ;jnz error_phuge
    ;scasd
    ;jnz error_phuge
    

    ;mov ax, [base_read+0x48]
    ;mov [dap_guid_table+8], ax
    emms
    movq mm0, [base_read+0x48]
    movq [dap_guid_table+8], mm0

    movzx eax, dword [base_read+0x50] ; eax = number of entries
    push eax
    movzx ebx, dword [base_read+0x54] ; ebx = entry size
    push ebx
    imul eax, ebx

    cmp eax, 492032-512*62
    ja error_phuge

    ; Ceiling division by 512
    add eax, 511
    shr eax, 9
    mov [dap_guid_table+2], ax

    call lba_drive_call             ; Read Partition Entry Array into base_read
    jc error_unknown_or_annoying

    pop ebx                         ; ebx = entry size
    pop eax                         ; eax = number of entries

    mov si, base_read
    mov cx, ax                      ; cx = loop counter

    movdqu xmm0, [mjpartid]

.loop_find_mj_partition:
    movdqu xmm1, [si]
    pcmpeqb xmm1, xmm0
    pmovmskb edi, xmm1
    not di
    test di, di
    jz .found

    add si, bx
    loop .loop_find_mj_partition

    jmp error_2nd_stage_copy

.found: 
    movdqu xmm2, [one]
    movdqu xmm3, [sixtytwo]

    movq xmm1, [si+40]              ; Ending LBA
    psubq xmm1, [si+32]             ; Ending LBA - Starting LBA
    paddq xmm1, xmm2                ; + 1
    psubq xmm1, xmm3                ; - 62
    psrlq xmm1, 63                  ; extract sign bit (1 if <62 sectors, 0 if >=62)
    
    ; FIX 2: Move size check result directly into EAX to test without memory writes
    movd eax, xmm1
    test al, al
    jnz error_2nd_stage_copy        ; Trigger "Drivesmol" only if sign bit is 1

    movdqu xmm0, [si+32]            ; Load 64-bit partition start LBA into xmm0
    jmp copy_2nd_stage

not_gpt:
    movdqu xmm0, [one]              ; Set start LBA to 1 for MBR gap
copy_2nd_stage:
    mov bx, 62
    mov si, dap_second_stage
    movdqu [si+8], xmm0             ; Write start LBA into DAP
    mov WORD [si+2], bx             ; Write sector count into DAP
    call lba_drive_call
    jc error_2nd_stage_copy

    jmp 0x0000:base_read            ; Jump to stage 2 bootloader

error_phuge:
    mov si, partitionshuge
    jmp error_stub

error_2nd_stage_copy:
    mov si, no2nd
    jmp error_stub

error_unknown_or_annoying:
    mov si, unknown

error_stub:
    call puts

infinite_halt:
    hlt
    jmp infinite_halt

lba_drive_call:
    mov ah, 0x42
    mov dx, bp                      ; restore boot drive number
    int 0x13
    ret

puts:
    cld 
    lodsb
    or al, al
    jz .return
    mov ah, 0x0e
    int 0x10
    jmp puts
.return:
    ret

data:
no2nd db "Drivesmol", 0x0
unknown db "DiskFault", 0x0
partitionshuge db "HugeP", 0x0
guidsig dq 0x5452415020494645 
mjpartid dd BYTE %(0x0d,0xda,0x6c,0xc0)
dw BYTE %(0xb5,0x65)
dw BYTE %(0xc7,0x49)
dw 0x54a9
dd 0x23475954     
dw 0x55c5
one dq 0x1
sixtytwo dq 62

dap_second_stage:
dap_signature:
dap_guid_table:
db 0x10
db 0x0
.size resw 1
.base_addr dw base_read
dw 0
.start resq 1

%assign binsize $-_start

%if binsize > 446
    %error "The bootloader code has exceeded 446 (size" %+ %!string binsize %+ " ), the maximum number allowed for mbr bootloaders!"
%else
    %warning "Bootloader size: " %+ %!string binsize %+ "."
%endif

times 446-($-$$) db 0
times 510-446 db 0
dw 0xAA55
