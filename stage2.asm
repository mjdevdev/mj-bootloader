bits 16
org 0x7c00+512

;transition to 32 bit mode then drop down to 16 bit unreal mode when doing graphics
start:
hlt
jmp start
