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

#include "y.tab.hh"

static  void yyunput (int c,char *buf_ptr);

std::string buffer;

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap
%option stack
%option verbose

%x quotes
%x command

%%

\" {
  buffer.clear();
  BEGIN(quotes);
}

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
  /* Exit the shell */
"exit" {
  exit(1);
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
(([^ \"\n\t\|\>\<\&\\])|(2\>)|(\\\")|(\\\n)|(\\\t)|(\\\>)|(\\\<)|(\\\&)|(\\\\))+ {
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
        if(next_quote == std::string::npos && buffer[next_quote - 1] != '\\') {
          buffer.erase(i,1);
          BEGIN(quotes);
          break;
        } else {
          buffer.erase(i, 1);  /* Delete the trailing " */
          buffer.erase(next_quote-1, 1); /* Delete the trailing " */
          i = next_quote - 1;
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

  /* Invalid character in input */
. {
  /* return NOTOKEN; */
}

