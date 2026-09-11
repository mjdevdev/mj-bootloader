
extern void puts(char *const); //hate header files
//constant pointer because dont want to change pointer, but modifying value is acceptable

extern void main_32();

extern void enter_protected_mode(void (*)());

char *lolxd = "haha idk what im doing\r\n\0";

char *lol = "DEBUG: 32 bit mode proved successful.";

/*extern*/ void main(){
  puts(lolxd);
  enter_protected_mode(main_32); 
  puts(lolxd);
}

void end(){
  puts(lol);
while(1) { 
      __asm__ volatile ("cli; hlt"); 
  }
}
