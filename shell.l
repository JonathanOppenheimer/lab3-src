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

#include <stdio.h>
#include <stdlib.h>

#include "shell.hh"
#include "y.tab.hh"

static void yyunput (int c ,char *buf_ptr);
std::string buffer; // Used to go through yytext
bool source; // A poor yet easy way to track if the command was source

void myunputc(int c) {
  unput(c);
}

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

  /* All source specific rules */
<manual_source>{
  [ \t]* {
    /* eat the whitespace */
  }

  \n { /* Didn't provide an arguement */ 
    std::cout << "source: usage: source filename [arguments]\n";
    BEGIN(INITIAL);
    return NEWLINE;
  }

  [^ \t\n]+ { /* Get the source file name */
    yyin = fopen(yytext, "r");
    if (!yyin) {
      std::cout << std::string(yytext) + ": No such file or directory\n";
      YY_FLUSH_BUFFER; // Flush yyin because we modified it
      BEGIN(INITIAL); // Finished reading file, go back to initial state */
      return NEWLINE;
    } else {
      yypush_buffer_state(yy_create_buffer(yyin, YY_BUF_SIZE));
      BEGIN(INITIAL); // Finished reading file, go back to initial state */
      source = true;
    }
  }
}

  /* Exit the shell */
"exit" {
  exit(0);
}

  /* New line character */
\n {
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
(([^ \n\t\|\>\<\&\\])|(2\>)|(\\\")|(\\\n)|(\\\t)|(\\\>)|(\\\<)|(\\\&)|(\\\\))+ {
    /* Set up the strings for use */
    buffer.clear();
    buffer += yytext;

    /* Parse the string for escaped characters and '"'. Deal with quotes.
     * In the case of an unclose '"', start the action to prompt the user 
     * to close it.
     */
    for(size_t i = 0; i < buffer.size(); ++i) {
      if(buffer[i] == '"') {
        int next_quote = buffer.find('"', i+1);
        std::cout << "pos:" << buffer[next_quote] << "," << std:string(next_quote) << "\n";

        if(next_quote == std::string::npos && buffer[next_quote - 1] != '\\') {
          buffer.erase(i,1);
          BEGIN(quotes);
          // break;
        } else {
          buffer.erase(i, 1);  /* Delete the first " */
          buffer.erase(next_quote-1, 1); /* Delete the trailing " */
          i = next_quote - 1;
        }
      }

      /* Trims escaped characters */
      if(buffer[i] == '\\') {
        buffer.erase(i,1);
        i++;
      }
    }

    /* Only return a word if we did not switch to another start condition */
    if(YY_START == INITIAL) {
      yylval.cpp_string = new std::string(buffer);
      return WORD;
    }
  }

  /* Invalid character in input */
. {
  /* return NOTOKEN; */
}

  /* Terminates the scanner - should happen by default but just double checking */
<<EOF>> {
  yypop_buffer_state();
  if (!YY_CURRENT_BUFFER) {
    yyterminate();
  }
}

