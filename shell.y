
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
//#define yylex yylex
#include <cstdio>
#include "shell.hh"

void yyerror(const char * s);
int yylex();

%}

%%

goal: command_list;
arg_list:
  arg_list WORD {
    Command::_currentSimpleCommand->insertArgument( $2 );
  }
  | /* can be empty */
;

cmd_and_args:
  WORD {
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
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

void
yyerror(const char * s)
{
  fprintf(stderr, "myshell: %s\n", s);
}

#if 0
main()
{
  yyparse();
}
#endif
