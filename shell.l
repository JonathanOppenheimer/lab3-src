
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include <iostream>
#include "y.tab.hh"

static  void yyunput (int c,char *buf_ptr  );

std::string buffer;
char string_buf[1000];
char *string_buf_ptr;

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%x quotes

%%

<quotes>{
  \" { /* saw closing quote - all done */
      BEGIN(INITIAL);
      *string_buf_ptr = '\0';
      /* return string constant token type and
       * value to parser
       */
  }

  \n {
      /* eat extra input */
  }


  \\n  buffer += '\n';
  \\t  *string_buf_ptr++ = '\t';
  \\r  *string_buf_ptr++ = '\r';
  \\b  *string_buf_ptr++ = '\b';
  \\f  *string_buf_ptr++ = '\f';

  \\(.|\n)  *string_buf_ptr++ = yytext[1];

  [^\\\n\"]+        {
    char *yptr = yytext;
    while ( *yptr ) {
      *string_buf_ptr++ = *yptr++;
    }
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

  /* Strip quotes from yytext and return it as a word */
  /* \".*\" {
  std::string* raw = new std::string(yytext);
  std::string trimmed = raw->substr(1, raw->size() - 2);
  yylval.cpp_string = new std::string(trimmed);
  return WORD;
  *}
  */

[^ \t\n"][^ \t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

  /* Invalid character in input */
. {
  return NOTOKEN;
}

