extern void puts_32(const char *);
extern void end();
extern void exit_protected_mode(void (*)());
char *const debug_msg = "DEBUG: successfully transitioned to 32 bit mode.";

void main_32(){
   char *somewhere_in_max_memory = (char *)0x00ffffff;
   *somewhere_in_max_memory = 'E'; //this wont crash meaning AGU allows more than 64 kb or 1mb if seg reg max
    //volatile char *vga = (volatile char *)0xB8000;
    //vga[0] = '3';
    //vga[1] = 0x0F; // White text attribute

    //while(1){
      //asm volatile("hlt");
     //}

   //puts_32(debug_msg);
   exit_protected_mode(end);
}
