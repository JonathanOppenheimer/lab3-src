
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <cstring>
#include <string>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN NEWLINE PIPE GREAT LESS TWOGREAT GREATAMPERSAND GREATGREAT GREATGREATAMPERSAND AMPERSAND
%define parse.error verbose

%{
#include <algorithm>
#include <cstdio>
#include <iostream>
#include <regex>
#include <string>
#include <vector>

#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "shell.hh"

void yyerror(const char * s);
void expandWildCardsIfNecessary(std::string*, std::vector<std::string>);
int isNotDirectory(const char *);
int yylex();

%}

%%

goal: command_list;
arg_list:
  arg_list WORD {
    std::vector<std::string> matching_args;
    expandWildCardsIfNecessary($2, matching_args);
  }
  | /* can be empty */
;

cmd_and_args:
  WORD {
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument($1);
  }
  arg_list {
    Shell::_currentCommand.insertSimpleCommand(Command::_currentSimpleCommand);
  }
;

pipe_list:
  cmd_and_args
  | pipe_list PIPE cmd_and_args
;

io_modifier:
    GREAT WORD { /* > */
      /* Redirect stdout */
      if(Shell::_currentCommand._outFile == NULL) {
        Shell::_currentCommand._outFile = $2;
      } else {
        Shell::_currentCommand._errorFlag = "Ambiguous output redirect.";
      }
    }
  | LESS WORD { /* < */
      /* Redirect stdin */
      if(Shell::_currentCommand._inFile == NULL) {
        Shell::_currentCommand._inFile = $2;
      } else {
        Shell::_currentCommand._errorFlag = "Ambiguous input redirect.";
      }
    }
  | TWOGREAT WORD { /* 2> */
      /* Redirect stderr */
      if(Shell::_currentCommand._errFile == NULL) {
        Shell::_currentCommand._errFile = $2;
      } else {
        Shell::_currentCommand._errorFlag = "Ambiguous error redirect.";
      }
    }
  | GREATAMPERSAND WORD { /* >& */
      /* Redirect stdout */
      if(Shell::_currentCommand._outFile == NULL) {
        Shell::_currentCommand._outFile = $2;
      } else {
        Shell::_currentCommand._errorFlag = "Ambiguous output redirect.";
      }

      /* Redirect stderr */
      if(Shell::_currentCommand._errFile == NULL) {
        Shell::_currentCommand._errFile = $2;
      } else {
        Shell::_currentCommand._errorFlag = "Ambiguous error redirection.";
      }
    }
  | GREATGREAT WORD { /* >> */
      /* Redirect stdout */
      if(Shell::_currentCommand._outFile == NULL) {
        Shell::_currentCommand._outFile = $2;
        Shell::_currentCommand._append = true;
      } else {
        Shell::_currentCommand._errorFlag = "Ambiguous output redirection";
      }
    }
  | GREATGREATAMPERSAND WORD { /* >>& */
      /* Redirect stdout */
      if(Shell::_currentCommand._outFile == NULL) {
        Shell::_currentCommand._outFile = $2;
        Shell::_currentCommand._append = true;
      } else {
        Shell::_currentCommand._errorFlag = "Ambiguous output redirection.";
      }

      /* Redirect stderr */
      if(Shell::_currentCommand._errFile == NULL) {
        Shell::_currentCommand._errFile = $2;
        Shell::_currentCommand._append = true;
      } else {
        Shell::_currentCommand._errorFlag = "Ambiguous error redirection.";
      }
    }
;

io_modifier_list:
  io_modifier_list io_modifier
  | /* empty */
;

background_optional:
    AMPERSAND {
      Shell::_currentCommand._background = true;
    }
;

command_line:
    pipe_list io_modifier_list NEWLINE {
      Shell::_currentCommand.execute();
    }
  | pipe_list io_modifier_list background_optional NEWLINE {
      Shell::_currentCommand.execute();
    }
  | NEWLINE {
      Shell::_currentCommand.execute();
    } /* accept empty cmd line */
  | error NEWLINE{
      yyerrok; /* Clear the errors */
    } /* error recovery */
;

command_list:
    command_line
  | command_list command_line
; /* command loop */

%%

void yyerror(const char* s) {
  fprintf(stderr, "myshell: %s\n", s);
}

void expandWildCardsIfNecessary(std::string* arg, std::vector<std::string> matching_args) {
  std::string raw_string = *arg;

  /* 
   * Build regex expression:
   * Replace * with .*
   * Replace ? with .
   * Replace . with \\.
   */
  for(int i=0; i<raw_string.length(); i++) {
    if(raw_string[i] == '*') {
      raw_string.replace(i, 1, ".*");
      i++;
    } else if(raw_string[i] == '?' ) {
      raw_string.replace(i, 1, ".");
    } else if(raw_string[i] == '.') {
      raw_string.replace(i, 1, "\\.");
      i++;
    }
  }

  std::cout << raw_string << "\n";

  // Finished building regex
  std::regex built_regex(raw_string);

  // Start directory search for matching directories
  DIR *dir; // The directory
  struct dirent *dp; // The directory stream of the directory
  dir = opendir(".");
  if (dir == NULL) {
    perror("opendir");
    return;
  }

  while ((dp = readdir(dir)) != NULL) {
    if (std::regex_match(dp->d_name, built_regex)) {
      // First check if the dp is not a directory
      if(isNotDirectory(dp->d_name)) {
        // Then check if it starts with a .
        if (dp->d_name[0] == '.') { // If it does only add if the word started with a .
          if ((*arg)[0] == '.')
            matching_args.push_back(std::string(dp->d_name));
        }
      } else { // Otherwise add it
        matching_args.push_back(std::string(dp->d_name));
      }
    }
    // std::cout << dp->d_name << "\n";
  }
  

  // Close the dir
  closedir(dir);

  // Sort the vector 
  std::sort(matching_args.begin(), matching_args.end());

  // Add the entries as arguements if matches found, otherwise
  for (int i = 0; i < matching_args.size(); i++) {
    Command::_currentSimpleCommand->insertArgument(new std::string(matching_args[i]));
  }
}

int isNotDirectory(const char *path) {
   struct stat statbuf;
   if (stat(path, &statbuf) != 0)
       return 0;
   return S_ISDIR(statbuf.st_mode);
}


#if 0
main()
{
  yyparse();
}
#endif
