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

void delete_char(int);
void insertChar(char);
void moveCursorLeft(int);
void moveCursorRight(int, int);
void wipeLine(int, int);

char line_buffer[MAX_BUFFER_LINE]; // Buffer where line is stored
int line_pos;                      // Where in the buffer we are
int total_chars;                   // Total number of characters in the buffer

std::vector<char *> history; // Keep previous commands here
int history_index = 0;       // Where in the history array we are

void read_line_print_usage() {
  std::string usage =
      "\n <ctrl-?>              Print usage information"
      "\n left arrow            Move cursor to the left"
      "\n right arrow           Move cursor to the right"
      "\n up arrow              See previous command in the history"
      "\n down arrow            See next command in the history"
      "\n <ctrl-D> / Delete     Removes the character at the cursor"
      "\n <ctrl-H> / Backspace  Removes the character at the position before "
      "the cursor"
      "\n <ctrl-A> / Home key   The cursor moves to the beginning of the line"
      "\n <ctrl-E> / End key    The cursor moves to the end of the line\n";
  write(1, usage.c_str(), usage.length());
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

    if ((in_char >= 32) && (in_char != 127)) { // Any printable character
      // Check whether we are writing at the end of the line, or within the line
      if (line_pos == total_chars) {             // At the start of the line
        insertChar(in_char);                     // Insert single character
        moveCursorRight(line_pos, line_pos + 1); // Move cursor right once
      } else { // We're somewhere within the line so need to adjust the cursor
        insertChar(in_char);             // Insert single character
        wipeLine(line_pos, total_chars); // Wipe all after current character
        moveCursorRight(line_pos, total_chars + 1); // Rewrite partial new line
        moveCursorLeft(total_chars - line_pos);     // Move cursor to prev pos
      }

      // Increment forward in buffer
      line_pos++;
      total_chars++;

      // If max number of character reached return.
      if (line_pos == MAX_BUFFER_LINE - 2)
        break;
    } else if (in_char == 1) { // <ctrl-A> / home key - move to line start
      moveCursorLeft(line_pos);
      line_pos = 0;
    } else if (in_char == 4) { // <ctrl-D> / delete key - delete character
      // Only delete if the line length is longer or equal to 0
      if ((line_pos >= 0) && (line_pos != total_chars)) { // Don't delete last
        delete_char(line_pos); // Delete the character
        total_chars--;

        wipeLine(line_pos, total_chars + 1); // Wipe all after current character
        moveCursorRight(line_pos, total_chars + 2); // Rewrite partial new line
        moveCursorLeft(total_chars - line_pos);     // Move cursor to prev pos
      }
    } else if (in_char == 5) { // <ctrl-E> / end key - move to line end
      moveCursorRight(line_pos, total_chars);
      line_pos = total_chars;
    } else if ((in_char == 8) || (in_char == 127)) { // <Backspace> / <ctrl-H>
      // Only delete if the line length is longer than 0
      if (line_pos > 0) {
        moveCursorLeft(1); // Move character back one
        line_pos--;
        delete_char(line_pos); // Delete the character
        total_chars--;

        wipeLine(line_pos, total_chars + 1); // Wipe all after current character
        moveCursorRight(line_pos, total_chars + 2); // Rewrite partial new line
        moveCursorLeft(total_chars - line_pos);     // Move cursor to prev pos
      }
    } else if (in_char == 10) { // <Enter> - return line
      line_pos = total_chars;
      // Add line to history vector
      history.push_back(line_buffer);

      // Print newline
      write(1, &in_char, 1);

      total_chars = 0;
      break;
    } else if (in_char == 31) { // <ctrl-?> - print help message
      read_line_print_usage();
      line_buffer[0] = 0;
      total_chars = 0;
      break;
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
        if (history.size() > 0) {       // Only show history if it exists
          // Move to start of line by printing backspaces
          moveCursorLeft(line_pos); // Move cursor to start of line
          wipeLine(0, total_chars); // Wipe the whole line

          // Copy line from history
          strcpy(line_buffer, history[history_index]);
          line_pos = strlen(line_buffer);
          total_chars = line_pos;
          history_index = (history_index + 1) % history.size();

          // echo line
          write(1, line_buffer, line_pos);
        }
      } else if ((ch1 == 91) && (ch2 == 66)) { // Down arrow

      } else if ((ch1 == 91) && (ch2 == 67)) { // Right arrow
        if (line_pos < total_chars) {
          moveCursorRight(line_pos, line_pos + 1);
          line_pos++;
        }
      } else if ((ch1 == 91) && (ch2 == 68)) { // Left arrow
        // Only go back if the current line position is greater than 0
        if (line_pos > 0) {
          moveCursorLeft(1); // Go back one character
          line_pos--;
        }
      }
    }
    ``
  }

  // Add eol and null char at the end of string before returning
  line_buffer[line_pos] = 10;
  line_pos++;
  line_buffer[line_pos] = 0;

  return line_buffer;
}

/*
 * Delete the character at the given position
 */
void delete_char(int pos) {
  for (int i = pos; i < total_chars; i++) {
    line_buffer[i] = line_buffer[i + 1];
  }
}

/*
 * Insert a character at the given position
 */
void insertChar(char in_char) {
  // Shift everything starting at the position forward
  for (int i = total_chars; i >= line_pos; i--) {
    line_buffer[i] = line_buffer[i - 1];
  }

  // Insert the character at the position
  line_buffer[line_pos] = in_char;
}

/*
 * Move the cursor left 'count' positions
 */
void moveCursorLeft(int count) {
  char back_char = 8;
  for (int i = 0; i < count; i++) {
    // Go back one character
    write(1, &back_char, 1);
  }
}

/*
 * Move the cursor to the right 'start - end' positions
 */
void moveCursorRight(int start, int end) {
  for (int i = start; i < end; i++) {
    write(1, &line_buffer[i], 1);
  }
}

/*
 * Given a start and end position, wipe the line from the given start to
 * the given end (inclusive on both ends)
 */
void wipeLine(int start, int end) {
  char write_char;

  // Print spaces on top to erase old line
  write_char = ' ';
  for (int i = start; i < end; i++) {
    write(1, &write_char, 1);
  }

  // Move to start of line by printing backspaces
  write_char = 8;
  for (int i = start; i < end; i++) {
    write(1, &write_char, 1);
  }
}
