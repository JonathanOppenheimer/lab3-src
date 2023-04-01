/*
 *
 * CS-252
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{
#include <algorithm>
#include <cstring>
#include <iostream>
#include <fstream>
#include <string>
#include <regex>

#include <fcntl.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <termios.h>
#include <unistd.h>

#include "shell.hh"
#include "y.tab.hh"

extern int yylex_destroy(void);
static void yyunput(int c ,char *buf_ptr);

bool source; // A poor yet easy way to track if the command was sourced
std::string buffer; // Used to go through yytext
std::string raw_subshell; // Used to parse subshell text
std::vector<int> opened_fds; // Used to keep track of opened file descriptors

void set_source() {
  if(isatty(0)) {
    char tstr[] = "source .shellrc\0\0"; // Write the command
    yy_scan_buffer(tstr, sizeof(tstr)); // Scan it
    yyparse(); // Reparse to get input from the user
    yylex_destroy(); // Destroy the buffer
  }
}

void myunputc(int c) {
  unput(c);
}

extern char* read_line();

int mygetc(FILE * f) {
  static char *p;
  char ch;
  if (!isatty(0)) {
    // stdin is not a tty. Call real getc
    return getc(f);
  }

  // stdin is a tty. Call our read_line.
  if (p==NULL || *p == 0) {
    char * s = read_line();
    p = s;
  }

  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)



%}

%option noyywrap
%option stack
%option verbose

%x quotes
%x manual_source

%%

  /* All quote specific rules "[xyz]" */
<quotes>{
  \" { /* saw closing quote - all done */
    BEGIN(INITIAL);
    yylval.cpp_string = new std::string(buffer);
    return WORD;
  }

  \n {
    buffer += yytext;
    /* Keep prompting for input */
    std::cout << "> ";
  }

  \\(.|\n) {
    buffer += "\\";
    buffer += yytext[1];
  }

  [^\\\n\"]+ {
    buffer += yytext;
  }
}

  /* Start source mode e.g. after source cmds.txt */
"source" {
  BEGIN(manual_source);
}

"exit" {
// Exit
  while (!opened_fds.empty()) {
    close(opened_fds.back());
    opened_fds.pop_back();
  }
  YY_FLUSH_BUFFER;

  // Restore terminal state
  tcsetattr(0, TCSANOW, &old_terminal_state);

  yylex_destroy(); // Destroy the buffer

  // Exit parent
  exit(0);
}

  /* All source specific rules */
<manual_source>{
  [ \t]* {
    /* eat the whitespace */
  }

  \n { /* Didn't provide an arguement */
    fprintf(stderr, "source: filename argument required\n");
    fprintf(stderr, "source: usage: source filename [arguments]\n");
    BEGIN(INITIAL);
    return NEWLINE;
  }

  [^ \t\n]+ { /* Get the source file name */
    FILE* sourced = fopen(yytext, "r");
    if (!sourced) {
      std::cout << std::string(yytext) + ": No such file or directory\n";
      YY_FLUSH_BUFFER; // Flush yyin because we modified it
      BEGIN(INITIAL); // Finished reading file, go back to initial state */
      return NEWLINE;
    } else {
      yypush_buffer_state(yy_create_buffer(sourced, YY_BUF_SIZE));
      BEGIN(INITIAL); // Finished reading file, go back to initial state */
      source = true;

      // Add the file descriptor to global array to close later on exit
      opened_fds.push_back(fileno(sourced));
    }
  }
}

\$\([^\n\)][^\n\)]*\) {
  // Add the parsed text to our temporary buffer 
  raw_subshell.clear();
  raw_subshell += yytext;

  // Delete the $( and )
  std::string trimmed = raw_subshell.substr(2, raw_subshell.length() - 3);

  // Append 'exit' to the command so we can leave the subshell
  trimmed += "\nexit\n";

  // Save old input and output
  int old_in = dup(0);
  int old_out = dup(1);

  // Create pipes for communication between the subshell and the shell -- PARENT
  int pin[2]; // Input of length 2
  int pout[2]; // Output of length
  pipe(pin);
  pipe(pout);

  // Write the command into the created in pipe
  write(pin[1], trimmed.c_str(), trimmed.length());
  close(pin[1]); // Already wrote, can close

  // Set up input to put into subshell
  // dup2(x, y): points y to x x->y
  dup2(pin[0], 0); // Points stdin to read end of the pipe
  dup2(pout[1], 1); // Points stdout to write end of the pipe
  close(pin[0]); // Can close original in of the pipe now that it's stdin
  close(pout[1]); // Can close original out of the pipe that that it's stdout

  // Set up the commands
  std::vector<char *> subshell_commands;
  std::string exe = "/proc/self/exe";
  subshell_commands.push_back((char *)exe.c_str());
  subshell_commands.push_back(NULL);

  // Execute the subshell commands
  int ret = fork();
  if(ret == 0) {
    execvp(subshell_commands[0], subshell_commands.data());
    perror("execvp");
    _exit(1);
  }

  // Now that command has been executed, need to restore old fds and close temps
  dup2(old_in, 0);
  dup2(old_out, 1);
  close(old_in);
  close(old_out);

  std::vector<char> results;
  char char_buffer[1];
  int eof = read(pout[0], char_buffer, 1);

  // Now we need to read from pout 0 and put it back into the buffer
  while(eof != 0) {
    if(*char_buffer == '\n') {
      results.push_back(' ');
    } else {
      results.push_back(*char_buffer);
    }
    eof = read(pout[0], char_buffer, 1);
  }

  while(!results.empty()) {
    char temp = results.back();
    // fprintf(stderr, "%c", temp);
    myunputc((int)(results.back()));
    results.pop_back();
  }

  // Clean up, close file
  close(pout[0]);
}

  /* New line character */
\n {
  std::cout << YY_CURRENT_BUFFER.rdbuf();
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

  /* Pipe */
"|" {
  return PIPE;
}

  /* Output redirection (stdout: 1 ) */
">" {
  return GREAT;
}

  /* Input redirection */
"<" {
  return LESS;
}

  /* Output redirection (stderr : 2) */
"2>" {
  return TWOGREAT;
}

  /* Output redirection (stdout and stderr : 1 and 2) */
">&" {
  return GREATAMPERSAND;
}

  /* Append output (stdout : 1) */
">>" {
  return GREATGREAT;
}

  /* Append output (stdout and stderr : 1 and 2) */
">>&" {
  return GREATGREATAMPERSAND;
}

  /* Run process in background */
"&" {
  return AMPERSAND;
}

  /* Match the majority of normal strings (non-special handled above)
   * Currently does not handle 2> as 2 is a normal character
   */
(([^ \n\t\|\>\<\&])|(2\>)|(\\\")|(\\\n)|(\\\t)|(\\\>)|(\\\<)|(\\\&)|(\\\\))+ {
    /* Set up the strings for use */
    buffer.clear();
    buffer += yytext;

    // Expand environment variables - catch a ${}
    std::regex container("\\$\\{.*\\}");
    if(std::regex_search(buffer, container)) {
      // Standard regex expression allowed characters: https://www.baeldung.com/linux/allowed-characters-variable-names
      std::regex standard("\\$\\{(?!_|SHELL)([A-Za-z0-9_]+)\\}");
      std::regex dollar("\\$\\{\\$\\}");
      std::regex question("\\$\\{\\?\\}");
      std::regex exclamation("\\$\\{!\\}");
      std::regex underscore("\\$\\{_\\}");
      std::regex name_shell("\\$\\{SHELL\\}");

      // Do simple (non-variable) regex replacements first
      buffer = std::regex_replace(buffer, dollar, std::to_string(getpid()));
      buffer = std::regex_replace(buffer, question, std::to_string(last_return_code));
      buffer = std::regex_replace(buffer, exclamation, std::to_string(last_background_pid));
      buffer = std::regex_replace(buffer, underscore, last_argument);
      buffer = std::regex_replace(buffer, name_shell, shell_location);

      // Do more standard regexes next 
      std::smatch matches; // Where to keep the results of the regex
      if(std::regex_search(buffer, standard)) {
        while(std::regex_search(buffer, matches, standard)) {
          std::regex cur_match("\\$\\{" + matches.str(1) + "\\}"); // Formulate specific regex
          if(getenv(matches.str(1).c_str())) { // If there are replace them with the expanded environment variable
            buffer = std::regex_replace(buffer, cur_match, getenv(matches.str(1).c_str()));
          } else { // If not delete the ${x}
            buffer = std::regex_replace(buffer, cur_match, "");
          }
        }
      }
    }
    // If anything else remains it must be a bad regex (non_valid env_vars) - so serror
    if(std::regex_search(buffer, container)) {
      std::cout << buffer + ": bad substitution\n";
      YY_FLUSH_BUFFER; // Flush yyin stop parsing
      return NEWLINE;
    }

    // Replace ~ section
    if(buffer[0] == '~') {
      struct passwd *pw; // User record structure

      // 3 cases - solo, before a user, or before a user/directory
      // Solo case:
      if(buffer.size() == 1) {
        buffer.replace(0, 1, getenv("HOME"));
      } else {
        size_t first_slash = buffer.find('/'); // Find the first / to see if we need to list subdirectory
        std::string user = buffer.substr(1, first_slash - 1);
        if ((pw = getpwnam(user.c_str())) == NULL) {
          // User could not be found - do not -- do not manipulated string
        } else { // Replace with found home directory
          if(first_slash == std::string::npos) { // Before a user
            buffer.replace(0, 1 + user.length(), pw->pw_dir);
          } else { // Before a user/directory
            buffer.replace(0, first_slash, pw->pw_dir);
          }
        }
      }
    }

    /* Parse the string for escaped characters and '"'. Deal with quotes.
     * In the case of an unclose '"', start the action to prompt the user 
     * to close it.
     */
    for(size_t i = 0; i < buffer.size(); ++i) {
      if(buffer[i] == '"') {
        int next_quote = buffer.find('"', i+1);
        // Checks to ensure the next quote is not escaped.
        if(next_quote == std::string::npos && buffer[next_quote - 1] != '\\') {
          buffer.erase(i,1);
          BEGIN(quotes);
        } else {
          buffer.erase(i, 1);  /* Delete the first " */
          buffer.erase(next_quote-1, 1); /* Delete the trailing " */
        }
      }

      /* Trims escaped characters */
      if(buffer[i] == '\\') {
        buffer.erase(i,1);
      }
    }

    /* Only return a word if we did not switch to another start condition */
    if(YY_START == INITIAL) {
      yylval.cpp_string = new std::string(buffer);
      return WORD;
    }
}

  /* Terminates the scanner - should happen by default but just double checking */
<<EOF>> {
  yypop_buffer_state();
  if (!YY_CURRENT_BUFFER) {
    yyterminate();
  }
  source = false;
}

