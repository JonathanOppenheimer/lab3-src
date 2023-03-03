
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
    printf("Yacc: insert arguement \"%s\"\n", $2->c_str());
    Command::_currentSimpleCommand->insertArgument( $2 );
  }
  | /* can be empty */
;

cmd_and_args:
  WORD {
    printf("Yacc: insert command \"%s\"\n", $1->c_str());
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
        yyerror("Ambigous output redirect\n");
      }
    }
  | LESS WORD { /* < */ 
      /* Redirect stdin */
      if(Shell::_currentCommand._inFile == NULL) {
        Shell::_currentCommand._inFile = $2;
      } else {
        yyerror("Ambigous input redirect\n");
        YYERROR; 
      }
    }
  | TWOGREAT WORD { /* 2> */ 
      /* Redirect stderr */
      if(Shell::_currentCommand._errFile == NULL) {
        Shell::_currentCommand._errFile = $2;
      } else {
        yyerror("Ambigous output redirect\n");
        YYERROR;
      }
    }
  | GREATAMPERSAND WORD { /* >& */
      /* Redirect stdout */
      if(Shell::_currentCommand._outFile == NULL) {
        Shell::_currentCommand._outFile = $2;
      } else {
        yyerror("Ambigous output redirect\n");
      }

      /* Redirect stderr */
      if(Shell::_currentCommand._errFile == NULL) {
        Shell::_currentCommand._errFile = $2;
      } else {
        yyerror("Ambigous output redirect\n");
      }
    }
  | GREATGREAT WORD { /* >> */
      /* Redirect stdout */
      if(Shell::_currentCommand._outFile == NULL) {
        Shell::_currentCommand._outFile = $2;
      } else {
        yyerror("Ambigous output redirect\n");
      }
    }
  | GREATGREATAMPERSAND WORD { /* >>& */
      /* Redirect stdout */
      if(Shell::_currentCommand._outFile == NULL) {
        Shell::_currentCommand._outFile = $2;
      } else {
        yyerror("Ambigous output redirect\n");
      }

      /* Redirect stderr */
      if(Shell::_currentCommand._errFile == NULL) {
        Shell::_currentCommand._errFile = $2;
      } else {
        yyerror("Ambigous output redirect\n");
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
  | /* empty */
;

command_line:
    pipe_list io_modifier_list NEWLINE {
      printf("   Yacc: Execute command\n");
      Shell::_currentCommand.execute();
    }
  | pipe_list io_modifier_list background_optional NEWLINE {
      printf("   Yacc: Execute command\n");
      Shell::_currentCommand.execute();
    }
  | NEWLINE{Shell::prompt();} /* accept empty cmd line */
  | error NEWLINE{
      yyerrok;
      Shell::prompt();
    }
; /*error recovery*/

command_list :
    command_line
  | command_list command_line
; /* command loop */

%%

void
yyerror(const char * s)
{
  fprintf(stderr,"my shell: %s %d\n", s, yychar);
}

#if 0
main()
{
  yyparse();
}
#endif
