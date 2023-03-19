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
  yy_push_state(quotes);
}

<quotes>{
  \" { /* saw closing quote - all done */
    yy_pop_state();
    buffer += yytext;
    buffer.erase(buffer.rfind('"'), 1); /* Delete the trailing " */
    yylval.cpp_string = new std::string(buffer);
    printf("Current buffer: %s\n", buffer.c_str());
    return WORD;
  }

  \n {
    buffer += yytext;
    /* Keep prompting for input */
    std::cout << "> ";
  }

  \\n  buffer += '\n';
  \\t  buffer += '\t';
  \\r  buffer += '\r';
  \\b  buffer += '\b';
  \\f  buffer += '\f';

  \\(.|\n) {
    buffer += yytext[1];
  }

  [^\\"\n]* {
    buffer += yytext;
  }
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

  /* Match everything but stuff covered by the above -
   * does not current deal with 2>
   */

[^ \n\t]* {
    /* Deals with escape characters */
    buffer.clear();
    buffer += yytext;
    std::string trimmed;
    for(size_t i = 0; i < buffer.size(); ++i) {

      if(buffer[i] == '"') {
        int next_quote = buffer.find('"', i+1);
        if(next_quote == std::string::npos && buffer[next_quote - 1] != '\\') {
          buffer.erase(i,1);
          yy_push_state(quotes);
          break;
        } else {
          buffer.erase(i, 1); /* Delete the trailing " */
          buffer.erase(next_quote-1, 1); /* Delete the trailing " */
        }
      }

      if(buffer[i] == '\\') {
        trimmed += buffer[i+1];
        i += 1;
      } else {
        trimmed += buffer[i];
      }
    }

    yylval.cpp_string = new std::string(trimmed);
    return WORD;
  }

  /* Invalid character in input */
. {
  return NOTOKEN;
}

