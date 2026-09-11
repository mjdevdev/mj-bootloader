extern void puts_32(const char *);
extern void end();
extern void exit_protected_mode(void (*)());
char *const debug_msg = "DEBUG: successfully transitioned to 32 bit mode.";

void main_32(){
   char *somewhere_in_max_memory = (char *)0x00ffffff;
   *somewhere_in_max_memory = 'E';
   //puts_32(debug_msg);
   exit_protected_mode(end);
}
