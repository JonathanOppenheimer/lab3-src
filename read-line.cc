/*
 * CS252: Systems Programming
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <iostream>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_BUFFER_LINE 2048

extern void tty_raw_mode(void);

// Buffer where line is stored
int line_length;
char line_buffer[MAX_BUFFER_LINE];

// Simple history array
// This history does not change.
// Yours have to be updated.
int history_index = 0;
char *history[] = {"ls -al | grep x", "ps -e", "cat read-line-example.c",
                   "vi hello.c",      "make",  "ls -al | grep xxx | grep yyy"};
int history_length = sizeof(history) / sizeof(char *);

void read_line_print_usage() {
  char *usage = "\n"
                " ctrl-?       Print usage\n"
                " Backspace    Deletes last character\n"
                " up arrow     See last command in the history\n";

  write(1, usage, strlen(usage));
}

/*
 * Input a line with some basic editing.
 */
char *read_line() {

  // Set terminal in raw mode
  tty_raw_mode();

  line_length = 0;

  // Read one line until enter is typed
  while (1) {

    // Read one character in raw mode.
    char in_char;
    read(0, &in_char, 1);
    // printf("%d\n", in_char);

    if ((in_char >= 32) && (in_char != 127)) {
      // Printable character that is not delete

      // Write the character out
      write(1, &in_char, 1);

      // If max number of character reached return.
      if (line_length == MAX_BUFFER_LINE - 2)
        break;

      // add char to buffer.
      line_buffer[line_length] = in_char;
      line_length++;
    } else if (in_char == 10) { // <Enter> - return line
      // Print newline
      write(1, &in_char, 1);

      break;
    } else if (in_char == 31) { // <ctrl-?> - print help message
      read_line_print_usage();
      line_buffer[0] = 0;

      break;
    } else if (in_char == 127) { // <Backspace> - remove previous character read
      // Only delete if the line length is longer than 0
      if (line_length > 0) {
        // Go back one character
        in_char = 8;
        write(1, &in_char, 1);

        // Write a space to erase the last character read
        in_char = ' ';
        write(1, &in_char, 1);

        // Go back one character
        in_char = 8;
        write(1, &in_char, 1);

        // Remove one character from buffer
        line_length--;
      }
    } else if (in_char == 27) {
      /* Escape sequence detected - read two chararacterss more to determine
       * exactly what key was pressed.
       *
       * up: 91 65
       * down: 91 66
       * right: 91 67
       * left: 91 68
       *
       */

      char ch1;
      char ch2;
      read(0, &ch1, 1);
      read(0, &ch2, 1);

      if ((ch1 == 91) && (ch2 == 65)) { // Up arrow - print next line in history
        // Move to start of line by printing backspaces
        int i = 0;
        for (i = 0; i < line_length; i++) {
          in_char = 8;
          write(1, &in_char, 1);
        }

        // Print spaces on top to erase old line
        for (i = 0; i < line_length; i++) {
          in_char = ' ';
          write(1, &in_char, 1);
        }

        // Move to start of line by printing backspaces
        for (i = 0; i < line_length; i++) {
          in_char = 8;
          write(1, &in_char, 1);
        }

        // Copy line from history
        strcpy(line_buffer, history[history_index]);
        line_length = strlen(line_buffer);
        history_index = (history_index + 1) % history_length;

        // echo line
        write(1, line_buffer, line_length);
      } else if ((ch1 == 91) && (ch2 == 66)) { // Down arrow
      } else if ((ch1 == 91) && (ch2 == 67)) { // Right arrow
                                               //
      } else if ((ch1 == 91) && (ch2 == 68)) { // Left arrow
        // Only go back if the current line position is greater than 0
        if (line_length > 0) {
          // Go back one character
          in_char = 8;
          write(1, &in_char, 1);
          line_length--;
        }
      }
    }
  }

  // Add eol and null char at the end of string before returning
  line_buffer[line_length] = 10;
  line_length++;
  line_buffer[line_length] = 0;

  return line_buffer;
}
