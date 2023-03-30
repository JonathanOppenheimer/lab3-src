
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
void getAllWildCards(std::string, std::string);
int isNotDirectory(const char *);
int yylex();

%}

%%

goal: command_list;
arg_list:
  arg_list WORD {
    std::vector<std::string> matching_args;

    std::string prefix = "";
    std::string suffix = *($2);
    if(suffix[0] != '/') { // Need to prepend ./ as it's not an absolute path
     suffix.insert(0, "./");
    }

    getAllWildCards(prefix, suffix);
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


void getAllWildCards(std::string prefix, std::string suffix) {
  if(suffix.length() == 0) { // Recursive expansion is done
    std::cout << "Prefix: " << prefix << "\n";
    std::cout << "Suffix: " << suffix << "\n";
    return;
  }

  // Deal with multi-level wildcards - start directory search for matching directories
  std::string::difference_type slash_count = std::count(suffix.begin(), suffix.end(), '/');

  // See if we're starting in . or /
  if(prefix.length() == 0) {
    int first_slash = suffix.find('/');
    prefix += suffix.substr(0, first_slash + 1);
    suffix.erase(0, first_slash + 1);
    getAllWildCards(prefix, suffix);
    return; // Do initial setup so we have have a prefix to open
  }

  // Expand the suffix to match possible directories

  std::string cur_level = suffix.substr(0, suffix.find('/'));
  std::string reg_cur_level = cur_level;
  suffix.erase(0, suffix.find('/'));
  bool need_to_expand = false;

  /* 
   * Build regex expression:
   * Replace * with .*
   * Replace ? with .
   * Replace . with \\.
   */
  for(int i=0; i < reg_cur_level.length(); i++) {
    if(reg_cur_level[i] == '*') {
      reg_cur_level.replace(i, 1, ".*");
      i++;
      need_to_expand = true;
    } else if(reg_cur_level[i] == '?' ) {
      reg_cur_level.replace(i, 1, ".");
      need_to_expand = true;
    } else if(reg_cur_level[i] == '.') {
      reg_cur_level.replace(i, 1, "\\.");
      i++;
    }
  }
  std::regex built_regex(reg_cur_level);

  if(!need_to_expand) {
    getAllWildCards(prefix + cur_level, suffix);
    return;
  }

  std::cout << "Prefix: " << prefix << "\n";
  std::cout << "cur_level: " << cur_level << "\n";
  std::cout << "Suffix: " << suffix << "\n";

  DIR *dir; // The directory
  struct dirent *dp; // The directory stream of the directory
  dir = opendir(prefix.c_str());
  if (dir == NULL) {
    perror("opendir");
    return;
  }

  while ((dp = readdir(dir)) != NULL) {
    if (std::regex_match(dp->d_name, built_regex)) {
      // First check if the dp is not a directory

      // Then check if it starts with a .
      if (dp->d_name[0] == '.') { // If it does only add if the word started with a .
        if(cur_level[0] == '.') {
          getAllWildCards(prefix + dp->d_name, suffix);
        }
      } else {
        getAllWildCards(prefix + dp->d_name, suffix);
      }
    }
  }

  // Close the dir
  closedir(dir);

}

void expandWildCardsIfNecessary(std::string* arg, std::vector<std::string> matching_args) {
  std::string raw_string = *arg;

  bool need_to_expand = false;

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
      need_to_expand = true;
    } else if(raw_string[i] == '?' ) {
      raw_string.replace(i, 1, ".");
      need_to_expand = true;
    } else if(raw_string[i] == '.') {
      raw_string.replace(i, 1, "\\.");
      i++;
    }
  }

  // Check if we actually need to do expansion
  if(!need_to_expand) {
    Command::_currentSimpleCommand->insertArgument(arg);
    return;
  }

  // Finished building regex
  std::regex built_regex(raw_string);

  // Set up current directory and stream
  DIR *dir; // The directory
  struct dirent *dp; // The directory stream of the directory
  dir = opendir("./.");
  if (dir == NULL) {
    perror("opendir");
    return;
  }

  while ((dp = readdir(dir)) != NULL) {
    if (std::regex_match(dp->d_name, built_regex)) {
      // First check if the dp is not a directory

      // Then check if it starts with a .
      if (dp->d_name[0] == '.') { // If it does only add if the word started with a .
        if((*arg)[0] == '.') {
          matching_args.push_back(std::string(dp->d_name));
        }
      } else {
        matching_args.push_back(std::string(dp->d_name));
      }
    }
  }
  

  // Close the dir
  closedir(dir);

  // Sort the vector 
  std::sort(matching_args.begin(), matching_args.end());

  // Add the entries as arguements if matches found, otherwise, just insert the original arg
  if(matching_args.size() > 0 ) {
    for (int i = 0; i < matching_args.size(); i++) {
      Command::_currentSimpleCommand->insertArgument(new std::string(matching_args[i]));
    }
  } else {
    Command::_currentSimpleCommand->insertArgument(arg);
  }
}

int isNotDirectory(const char *path) {
  struct stat statbuf;
  if (stat(path, &statbuf) != 0) {
    return 0;
  } else {
    return S_ISDIR(statbuf.st_mode);
  }
}


#if 0
main()
{
  yyparse();
}
#endif
