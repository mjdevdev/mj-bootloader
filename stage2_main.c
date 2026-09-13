#include <stdint.h>
#include <stddef.h>

struct VesaInfoBlock {
   char     VbeSignature[4];         // == "VESA"
   uint16_t VbeVersion;              // == 0x0300 for VBE 3.0
   uint16_t OemStringPtr[2];         // isa vbeFarPtr
   uint8_t  Capabilities[4];
   uint16_t VideoModePtr[2];         // isa vbeFarPtr
   uint16_t TotalMemory;             // as # of 64KB blocks
   uint8_t  Reserved[492];
} __attribute__((packed));

static void* memcpy(void* dest, const void* src, size_t n) {
    unsigned char* d = (unsigned char*)dest;
    const unsigned char* s = (const unsigned char*)src;
    for (size_t i = 0; i < n; i++) {
        d[i] = s[i];
    }
    return dest;
}


static char read_far_byte(uint16_t seg, uint16_t off) {
    char val;
    asm volatile(
        "push %%gs\n\t"
        "mov %1, %%gs\n\t"
        "mov %%gs:(%2), %0\n\t"  
        "pop %%gs"
        : "=r"(val)
        : "r"(seg), "S"(off)     
        : "memory"
    );
    return val;
}

struct VesaInfoBlock vesaBlock = {.VbeSignature = "VBE2", .VbeVersion=0x200};

extern uint16_t getVBEInfo(struct VesaInfoBlock *);

static char *lol = " \r\n";

extern void puts(const char*);

void stage2_main(){
  if((uint32_t)&vesaBlock >= (uint32_t) 0x0fffff){
    puts("what kind of pointer bro \r\n");
    while(1){
     asm volatile("hlt");
    }
  }else if ((uint32_t)&vesaBlock + sizeof(struct VesaInfoBlock)-1 > 0x100000) {
    puts("Buffer extends past 1MB real-mode barrier!\r\n");
    while(1){
     asm volatile("hlt");
    }
   }
  uint16_t result = getVBEInfo(&vesaBlock);
  if(result >> 8 || (result & 0xff) != 0x4F) {
    puts("Function not supported, or invalid in current video mode. :( \r\n");

    puts("ERROR CODE:");

    lol[0] += result >> 8;
    puts(lol);
    
    while(1){
      asm volatile("hlt");
    }
  }
  
    uint16_t offset = vesaBlock.OemStringPtr[0];
  uint16_t segreg = vesaBlock.OemStringPtr[1];

  puts("OEM String: ");
  
  // Loop and print character-by-character using our far-read helper
  for (int i = 0; i < 64; i++) {
      char c = read_far_byte(segreg, offset + i);
      if (c == '\0') break; // Stop at null terminator

      char buf[2] = { c, '\0' };
      puts(buf);
  }
  puts("\r\n");

  
}
