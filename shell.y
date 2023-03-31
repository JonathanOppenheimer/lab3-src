
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
void expandWildcards(std::string, std::string, std::vector<std::string *>& matching_args);
int isDirectory(const char *);
int yylex();

%}

%%

goal: command_list;
arg_list:
  arg_list WORD {
    // Wild card expansion below
    std::string prefix = "";
    std::string suffix = *($2);
    if(suffix[0] != '/') { // Need to prepend ./ as it is not an absolute path
      suffix.insert(0, "./");
    }

    // Get all the wild cards given the prefix and the suffix and store them in a vector
    std::vector<std::string *> matching_args;
    expandWildcards(prefix, suffix, matching_args);

    // Sort the vector with the matching results
    std::sort(matching_args.begin(), matching_args.end(), [](std::string * a, std::string * b) { return *a < *b; });

    // Add the entries as arguments if matches were found, otherwise, insert the original argument (bash default behavior)
    if(matching_args.size() > 0 ) {
      for (int i = 0; i < matching_args.size(); i++) {
        Command::_currentSimpleCommand->insertArgument(matching_args[i]);
      }
    } else {
      Command::_currentSimpleCommand->insertArgument( $2 );
    }
    matching_args.clear(); // Clear memory used in vector
    matching_args.shrink_to_fit();
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


void expandWildcards(std::string prefix, std::string suffix, std::vector<std::string *>& matching_args) {
  /***************** Two end conditions *****************/

  // The first is that the suffix is empty - we were searching for files and folder
  if(suffix.length() == 0) { 
    // Don't include the fake prefix if we we added if it
    if(prefix.substr(0,2) == "./") {
      matching_args.push_back(new std::string(prefix.erase(0, 2)));
    } else {
      matching_args.push_back(new std::string(prefix));
    }
    return;
  }

  // The second is that the suffix is a single '/' - we were just searching for folders
  if(suffix == "/") { 
    // Don't include the fake prefix if we we added if it
    if(prefix.substr(0,2) == "./") {
      matching_args.push_back(new std::string(prefix.erase(0, 2) + "/"));
    } else {
      matching_args.push_back(new std::string(prefix + "/"));
    }
    return;
  }

  /*******************************************************/

  // See if we're starting in . or / - can't search an empty directory
  if(prefix.length() == 0) {
    prefix += suffix.substr(0, suffix.find('/') + 1);
    suffix.erase(0, suffix.find('/') + 1);
    expandWildcards(prefix, suffix, matching_args);
    return; // Do initial setup so we have have a prefix to open
  }

  // Expand the suffix to match possible directories

  // Find what the current level regex will be - essentially the regex for one folder level

  // The level we're searching e.g. homes/jop*nhe/*
  std::string cur_level; //         PREFIX C_LVL  SUFFIX
  if(std::count(suffix.begin(), suffix.end(), '/') == 0) { // No more / in suffix, add everything to current level 
    cur_level = suffix.substr(0, suffix.length());
    suffix.erase(0, suffix.length());
  } else {
    if(suffix[0] == '/') { // Shift the / over one and try again - non-terminal /
      prefix += suffix.substr(0, 1);
      suffix.erase(0, 1);
      expandWildcards(prefix, suffix, matching_args);
      return;
    } else { // Make the current level everything to next /
      cur_level = suffix.substr(0, suffix.find('/'));
      suffix.erase(0, suffix.find('/'));
    }
  }

  // Now check if expansion is necessary - does the current level have wildcards?
  std::string::difference_type num_star = std::count(cur_level.begin(), cur_level.end(), '*');
  std::string::difference_type num_q = std::count(cur_level.begin(), cur_level.end(), '?');

  // Expansion is not necessary
  if(num_star + num_q == 0) {
    expandWildcards(prefix + cur_level, suffix, matching_args);
    return;
  }

  // Expansion is necessary
  std::string reg_cur_level = cur_level;

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
    } else if(reg_cur_level[i] == '?' ) {
      reg_cur_level.replace(i, 1, ".");
    } else if(reg_cur_level[i] == '.') {
      reg_cur_level.replace(i, 1, "\\.");
      i++;
    }
  }
  std::regex built_regex(reg_cur_level);

  DIR *dir; // The directory
  struct dirent *dp; // The directory stream of the directory
  dir = opendir(prefix.c_str());
  if (dir == NULL) {
    perror("opendir");
    return;
  }

  // Recursively call wildcard expansion, depending on conditions
  while ((dp = readdir(dir)) != NULL) {
    if (std::regex_match(dp->d_name, built_regex)) {
      bool include_start_period = cur_level[0] == '.'; // Whether we include files that start with a .
      bool start_period = dp->d_name[0] == '.'; // Whether the file starst with a .
      bool include_files = suffix.length() == 0; // Whether we include files that are directories
      bool is_directory = isDirectory((prefix + dp->d_name).c_str()); // Whether the file is a directory
 
      if(include_start_period && start_period) {
        if(!include_files && is_directory) {
          expandWildcards(prefix + dp->d_name, suffix, matching_args);
        } else if(include_files) {
          expandWildcards(prefix + dp->d_name, suffix, matching_args);
        }
      } else {
        if(!include_files && is_directory && !start_period) {
          expandWildcards(prefix + dp->d_name, suffix, matching_args);
        } else if(include_files && !start_period) {
          expandWildcards(prefix + dp->d_name, suffix, matching_args);
        }
      }
    }
  }
  
  regfree(&built_regex);

  // Close the directory
  closedir(dir);
}
 
int isDirectory(const char *path) {
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
