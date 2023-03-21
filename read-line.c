/*
 * CS252: Systems Programming
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define MAX_BUFFER_LINE 2048

extern void tty_raw_mode(void);

// Buffer where line is stored
int line_length;
char line_buffer[MAX_BUFFER_LINE];
int line_pos;
// Simple history array
// This history does not change. 
// Yours have to be updated.
int history_index = 0;
char * history [] = {
  "ls -al | grep x", 
  "ps -e",
  "cat read-line-example.c",
  "vi hello.c",
  "make",
  "ls -al | grep xxx | grep yyy"
};
int history_length = sizeof(history)/sizeof(char *);

void read_line_print_usage()
{
  char * usage = "\n"
    " ctrl-?       Print usage\n"
    " Backspace    Deletes last character\n"
    " up arrow     See last command in the history\n";

  write(1, usage, strlen(usage));
}

/* 
 * Input a line with some basic editing.
 */
char * read_line() {

  // Set terminal in raw mode
  tty_raw_mode();

  line_length = 0;
  

  // Read one line until enter is typed
  while (1) {

    // Read one character in raw mode.
    char ch;
    read(0, &ch, 1);

    if (ch>=32 && ch!=127) {
      // It is a printable character. 

      // Do echo
      write(1,&ch,1);

      // If max number of character reached return.
      if (line_length==MAX_BUFFER_LINE-2) break; 
      
      if(line_length == line_pos){
        line_buffer[line_length] = ch;
        line_length++;
        line_pos++;
      }else if(line_length>line_pos){
        char oldCh = line_buffer[line_pos];
        line_length++;
        line_buffer[line_pos] = ch;
        
        for(int i = line_pos +1; i <line_length; i++){
          ch = line_buffer[i];
          line_buffer[i] = oldCh;
          write(1, &oldCh, 1);
          oldCh = ch;
        }
        for(int i = 0; i <line_length-line_pos-1; i++){
          ch = 8;
          write(1, &ch, 1);
        }
        line_pos++;

      }

    }
    else if (ch==10) {
      // <Enter> was typed. Return line
      line_pos = 0;      
      // Print newline
      write(1,&ch,1);

      break;
    }
    else if (ch == 31) {
      // ctrl-?
      read_line_print_usage();
      line_buffer[0]=0;
      break;
    }
    else if (ch == 8) {
      // <backspace> was typed. Remove previous character read.

      // Go back one character
      ch = 8;
      write(1,&ch,1);

      // Write a space to erase the last character read
      ch = ' ';
      write(1,&ch,1);

      // Go back one character
      ch = 8;
      write(1,&ch,1);

      // Remove one character from buffer
      line_length--;
    }
    else if (ch==27) {
      // Escape sequence. Read two chars more
      //
      // HINT: Use the program "keyboard-example" to
      // see the ascii code for the different chars typed.
      //
      char ch1; 
      char ch2;
      read(0, &ch1, 1);
      read(0, &ch2, 1);
      if (ch1==91 && ch2==65) {
	// Up arrow. Print next line in history.

	// Erase old line
	// Print backspaces
	int i = 0;
	for (i =0; i < line_length; i++) {
	  ch = 8;
	  write(1,&ch,1);
	}

	// Print spaces on top
	for (i =0; i < line_length; i++) {
	  ch = ' ';
	  write(1,&ch,1);
	}

	// Print backspaces
	for (i =0; i < line_length; i++) {
	  ch = 8;
	  write(1,&ch,1);
	}	

	// Copy line from history
	strcpy(line_buffer, history[history_index]);
	line_length = strlen(line_buffer);
	history_index=(history_index+1)%history_length;

	// echo line
	write(1, line_buffer, line_length);
      }
      if(ch1==91 && ch2==66){
        //down arrow key
        int i = 0;
        for(i = 0; i <line_length; i++){
          ch=8;
          write(1,&ch,1);
        }
        for(i=0; i<line_length; i++){
          ch=' ';
          write(1,&ch,1);
        }
        for(i=0; i<line_length; i++){
          ch=8;
          write(1,&ch,1);
        }
        strcpy(line_buffer, history[history_index]);
        line_length = strlen(line_buffer);
        history_index=(history_index+1)%history_length;

        // echo line
        write(1, line_buffer, line_length);
      }
      if (ch1==91 && ch2==68 && line_pos>0){
        //left arrow key
        ch = 8;
        write(1,&ch,1);
        line_pos--;
        //insertion
      
      }
      if(ch1 == 91 && ch2==67 && line_pos<=line_length){
        //right arrow
        ch = line_buffer[line_pos];
        write(1, &ch, 1);
        line_buffer[line_pos] = ch;
        line_pos++;

        //insertion

      }
      if(ch1 == 4){
        //delete a char at the cursor
      }
      if(ch1 == 1){
        //home, cursor moves to beginning of line
      }
      if(ch1 == 5){
        //end, cursor moves to end of line
      }
    

      


      
    }

  }

  // Add eol and null char at the end of string
  line_buffer[line_length]=10;
  line_length++;
  line_buffer[line_length]=0;

  return line_buffer;
}

