/*
 * CS252: Systems Programming
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <algorithm>
#include <cstddef>
#include <cstdio>

#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <regex>
#include <string>
#include <vector>

#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define MAX_BUFFER_LINE 2048

extern void tty_raw_mode(void);

void delete_char(int);
void insertChar(char);
void moveCursorLeft(int);
void moveCursorRight(int, int);
void restorePreviousLine();
void wipeLine(int, int);

void getMatchingFiles(std::string, std::vector<std::string> &matching_args);
std::string longestCommonPrefix(std::vector<std::string> &strings);

char line_buffer[MAX_BUFFER_LINE]; // Buffer where line is stored
int line_pos;                      // Where in the buffer we are
int total_chars;                   // Total number of characters in the buffer

std::vector<std::string> history; // Keep previous commands here
int history_index = 0;            // Where in the history array we are

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

  // Reset the line buffer
  memset(line_buffer, 0, total_chars);
  total_chars = 0;

  // std::cout << line_buffer << "\n";

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
        insertChar(in_char);                 // Insert single character
        wipeLine(line_pos, total_chars + 1); // Wipe all after current character
        moveCursorRight(line_pos,
                        total_chars + 1 + 1);   // Rewrite partial new line
        moveCursorLeft(total_chars - line_pos); // Move cursor to prev pos
      }

      // Increment forward in buffer
      line_pos++;
      total_chars++;

      // If max number of character reached return.
      if (line_pos == MAX_BUFFER_LINE - 2) {
        break;
      }
    } else if (in_char == 1) { // <ctrl-A> / home key - move to line start
      moveCursorLeft(line_pos);
      line_pos = 0;
    } else if (in_char == 4) { // <ctrl-D> / delete key - delete character
      // Only delete if the line length is longer or equal to 0
      if ((line_pos >= 0) && (line_pos != total_chars)) { // Don't delete last
        delete_char(line_pos); // Delete the character
        total_chars--;

        wipeLine(line_pos, total_chars + 1); // Wipe all after current character
        moveCursorRight(line_pos, total_chars + 1); // Rewrite partial new line
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
        moveCursorRight(line_pos, total_chars + 1); // Rewrite partial new line
        moveCursorLeft(total_chars - line_pos);     // Move cursor to prev pos
      }
    } else if (in_char == 9) {                // <tab> - autocomplete
      moveCursorRight(line_pos, total_chars); // Move to end of the line
      line_pos = total_chars;

      /* Can use the current 'word' (right most string when strings are
       * seperated by spaces), as a regex for expandWildcards. Once the regex
       * returns the matches, we can parse them to see how to update the
       * terminal. If the matches is of size 1, we can autocomplete. If not,
       * find the largest common prefix among the matches and print that. If
       * the greatest common prefix is already in the terminal, print possible
       * matches to the terminal
       */

      // Get the last word in the buffer
      int first_char = 0;
      for (int i = total_chars - 1; i >= 0; i--) {
        if (line_buffer[i] == ' ') {
          first_char = i + 1;
          break;
        }
      }

      // Build last word string
      std::string last_word = "";
      for (int i = first_char; i < total_chars; i++) {
        last_word += line_buffer[i];
      }

      // Make the wildcard expansion call
      std::string wild_last_word = last_word;
      wild_last_word.append("*");
      std::vector<std::string> matching_args;
      getMatchingFiles(wild_last_word, matching_args);

      // Sort the vector with the matching results
      std::sort(matching_args.begin(), matching_args.end(),
                [](std::string a, std::string b) { return a < b; });

      // Check to see how many matches there were
      if (matching_args.size() == 1) { // Exact match
        std::string match = matching_args.at(0);
        // Print the remainder of the match
        for (int i = (total_chars - first_char); i < match.size(); i++) {
          insertChar(match[i]);                    // Insert single character
          moveCursorRight(line_pos, line_pos + 1); // Move cursor right once
          line_pos++;
          total_chars++;
        }
      } else if (matching_args.size() > 1) {
        // Get the longest common prefix to autocomplete
        std::string lcp = longestCommonPrefix(matching_args);

        if (total_chars - first_char <
            lcp.size()) { // We have some of an LCP to print
          // Print the remainder of the LCP
          for (int i = (total_chars - first_char); i < lcp.size(); i++) {
            insertChar(lcp[i]);                      // Insert single character
            moveCursorRight(line_pos, line_pos + 1); // Move cursor right once
            line_pos++;
            total_chars++;
          }
        } else {                  // We do not - need to print possibilities
          size_t field_width = 0; // length of longest text
          for (int i = 0; i < matching_args.size(); i++) {
            field_width = std::max(matching_args.at(i).length(), field_width);
          }

          // Get information about the terminal to format output nicely
          struct winsize w;
          ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
          int chars_printed = 0;
          std::cout << "\n";
          for (int i = 0; i < matching_args.size(); i++) { // Print out matches
            if (chars_printed + (field_width + 2) +
                    matching_args.at(i).length() >
                w.ws_col) { // Enter new line if we'd go over alloted width
              std::cout << std::endl;
              chars_printed = 0;
            }
            std::cout << std::left << std::setw(field_width + 2)
                      << matching_args.at(i);
            chars_printed += (field_width + 2) + matching_args.at(i).length();
          }
          std::cout << std::endl;
          restorePreviousLine();
        }
      }

      matching_args.clear(); // Clear memory used in vector
      matching_args.shrink_to_fit();
    } else if (in_char == 10) { // <Enter> - return line
      line_pos = total_chars;
      // Add line to history vector
      std::string history_item = std::string(line_buffer);
      history_item.erase(
          std::remove(history_item.begin(), history_item.end(), '\n'),
          history_item.end());
      history.push_back(history_item);

      // Print newline
      write(1, &in_char, 1);
      break;
    } else if (in_char == 31) { // <ctrl-?> - print help message
      read_line_print_usage();
      line_buffer[0] = 0;
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
          moveCursorLeft(line_pos);     // Move cursor to start of line
          wipeLine(0, total_chars + 1); // Wipe the whole line

          // Copy line from history
          strcpy(line_buffer, history.at(history_index).c_str());
          line_pos = strlen(line_buffer);
          total_chars = line_pos;
          history_index = (history_index + 1) % history.size();

          // echo line
          write(1, line_buffer, line_pos);
        }
      } else if ((ch1 == 91) && (ch2 == 66)) { // Down arrow
        // Move to start of line by printing backspaces
        moveCursorLeft(line_pos);     // Move cursor to start of line
        wipeLine(0, total_chars + 1); // Wipe the whole line

        // Copy line from history
        strcpy(line_buffer, history.at(history_index).c_str());
        line_pos = strlen(line_buffer);
        total_chars = line_pos;
        history_index = ((history_index - 1) + history.size()) % history.size();

        // echo line
        write(1, line_buffer, line_pos);
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
 * Restores the line the user was on - myshell>line contents
 */
void restorePreviousLine() {
  // Check if a custom prompt exists
  char *custom_prompt = getenv("PROMPT");
  if (custom_prompt != NULL) { // Print the custom one
    write(1, custom_prompt, strlen(custom_prompt));
  } else { // Print myshell>
    char default_prompt[] = {'m', 'y', 's', 'h', 'e', 'l', 'l', '>'};
    write(1, default_prompt, 8);
  }

  // Restore what was in the buffer
  write(1, line_buffer, total_chars);
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

void getMatchingFiles(std::string wild_last_word,
                      std::vector<std::string> &matching_args) {
  if (wild_last_word[0] != '/') { // In current directory
    wild_last_word.insert(0, "./");
  }

  // Find where we should expanding
  std::string directory_path = "";
  while (wild_last_word.find('/') != std::string::npos) {
    if (directory_path.length() == 0) {
      directory_path += wild_last_word.substr(0, wild_last_word.find('/') + 1);
      wild_last_word.erase(0, wild_last_word.find('/') + 1);
    } else {

      if (wild_last_word[0] ==
          '/') { // Shift the / over one and try again - non-terminal /
        directory_path += wild_last_word.substr(0, 1);
        wild_last_word.erase(0, 1);
      } else { // Make the current level everything to next /
        directory_path += wild_last_word.substr(0, wild_last_word.find('/'));
        wild_last_word.erase(0, wild_last_word.find('/'));
      }
    }
  }

  std::string regex = wild_last_word;

  /*
   * Build regex expression:
   * Replace * with .*
   * Replace ? with .
   * Replace . with \\.
   */
  for (int i = 0; i < regex.length(); i++) {
    if (regex[i] == '*') {
      regex.replace(i, 1, ".*");
      i++;
    } else if (regex[i] == '?') {
      regex.replace(i, 1, ".");
    } else if (regex[i] == '.') {
      regex.replace(i, 1, "\\.");
      i++;
    }
  }
  std::regex built_regex(regex);

  DIR *dir;          // The directory
  struct dirent *dp; // The directory stream of the directory
  dir = opendir(directory_path.c_str());
  if (dir == NULL) {
    return; // Fake directory, return
  }

  // Recursively call wildcard expansion, depending on conditions
  while ((dp = readdir(dir)) != NULL) {
    if (std::regex_match(dp->d_name, built_regex)) {
      if (directory_path[0] == '.') { // Don't append directory for local
        matching_args.push_back(std::string(dp->d_name));
      } else {
        matching_args.push_back(std::string(directory_path + dp->d_name));
      }
    }
  }

  // Close the directory
  closedir(dir);
}

std::string longestCommonPrefix(std::vector<std::string> &strings) {
  std::string prefix = "";
  std::string a = strings[0];
  std::string b = strings[strings.size() - 1];

  for (int i = 0; i < a.size(); i++) {
    if (a[i] == b[i]) {
      prefix = prefix + a[i];
    } else {
      break;
    }
  }

  return prefix;
}
