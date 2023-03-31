/*
 * CS252: Systems Programming
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <iostream>
#include <vector>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_BUFFER_LINE 2048

extern void tty_raw_mode(void);
void insertChar(char);
void moveCursorRight(int, int);
void wipeLine(int, int);

char line_buffer[MAX_BUFFER_LINE]; // Buffer where line is stored
int line_pos;                      // Where in the buffer we are
int total_chars;                   // Total number of characters in the buffer

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

  line_pos = 0;

  // Read one line until enter is typed
  while (1) {

    // Read one character in raw mode.
    char in_char;
    read(0, &in_char, 1);
    // printf("%d\n", in_char);

    if ((in_char >= 32) && (in_char != 127)) {
      // Printable character that is not delete

      // Check whether we are writing at the end of the line, or within the line
      if (line_pos == total_chars) { // At the start of the line

        // Write the character out
        write(1, &in_char, 1);
        // add char to buffer.
        line_buffer[line_pos] = in_char;
        line_pos++;
        total_chars++;
      } else { // We're somewhere within the line
        insertChar(in_char);
        wipeLine(line_pos, total_chars);
        moveCursorRight(line_pos, total_chars);
        for (int i = 0; i < total_chars - line_pos; i++) {
          // Go back one character
          in_char = 8;
          write(1, &in_char, 1);
        }

        line_pos++;
        total_chars++;
      }

      // If max number of character reached return.
      if (line_pos == MAX_BUFFER_LINE - 2)
        break;

      // Increment total_chars
    } else if (in_char == 10) { // <Enter> - return line
      // Print newline
      moveCursorRight(line_pos, total_chars);
      write(1, &in_char, 1);
      total_chars = 0;
      break;
    } else if (in_char == 31) { // <ctrl-?> - print help message
      read_line_print_usage();
      line_buffer[0] = 0;
      total_chars = 0;
      break;
    } else if (in_char == 127) { // <Backspace> - remove previous character read
      // Only delete if the line length is longer than 0
      if (line_pos > 0) {
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
        line_pos--;
        total_chars--; // Decrement total_chars
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
        // Wipe current line
        wipeLine(0, total_chars);

        // Copy line from history
        strcpy(line_buffer, history[history_index]);
        line_pos = strlen(line_buffer);
        total_chars = line_pos;
        history_index = (history_index + 1) % history_length;

        // echo line
        write(1, line_buffer, line_pos);
      } else if ((ch1 == 91) && (ch2 == 66)) { // Down arrow
      } else if ((ch1 == 91) && (ch2 == 67)) { // Right arrow
        if (line_pos < total_chars) {
          // Write the character out
          write(1, &line_buffer[line_pos], 1);
          line_pos++;
        }
      } else if ((ch1 == 91) && (ch2 == 68)) { // Left arrow
        // Only go back if the current line position is greater than 0
        if (line_pos > 0) {
          // Go back one character
          in_char = 8;
          write(1, &in_char, 1);
          line_pos--;
        }
      }
    }
  }

  // Add eol and null char at the end of string before returning
  line_buffer[line_pos] = 10;
  line_pos++;
  line_buffer[line_pos] = 0;

  return line_buffer;
}

void insertChar(char in_char) {
  // Shift everything starting at the position forward
  for (int i = total_chars; i >= line_pos; i--) {
    line_buffer[i] = line_buffer[i - 1];
  }

  // Insert the character at the position
  line_buffer[line_pos] = in_char;
}

void moveCursorRight(int start, int end) {
  for (int i = start; i <= end; i++) {
    write(1, &line_buffer[i], 1);
  }
}

/*
 * Given a start and end position, wipe the line from the given start to
 * the given end (inclusive on both ends)
 */
void wipeLine(int start, int end) {
  char write_char;

  // Move to start by printing backspaces
  for (int i = 0; i <= end - start; i++) {
    write(1, &write_char, 1);
  }

  // Print spaces on top to erase old line
  write_char = ' ';
  for (int i = 0; i <= end - start; i++) {
    write(1, &write_char, 1);
  }

  // Move to start of line by printing backspaces
  write_char = 8;
  for (int i = 0; i <= end - start; i++) {
    write(1, &write_char, 1);
  }
}
