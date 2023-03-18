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

%x quotes

%%

\" {
  BEGIN(quotes);
  buffer.clear();
}

<quotes>{
  \"[^ \t\n\"]* { /* saw closing quote - all done */
    BEGIN(INITIAL);
    buffer += yytext;
    // buffer.erase(std::remove(buffer.begin(), buffer.end(), '"'), buffer.end());
    buffer.erase(buffer.rfind('"'), 1); /* Delete the trailing " */
    yylval.cpp_string = new std::string(buffer);
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

  [^\\\n\"]+ {
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

 /* Strip quotes from yytext and return it as a word */
  /* \".*\" {
  std::string* raw = new std::string(yytext);
  std::string trimmed = raw->substr(1, raw->size() - 2);
  yylval.cpp_string = new std::string(trimmed);
  return WORD;
  } */

^((?! )(?!\")(?!\n)(?!\t)(?!\|)(?!>)(?!<)(?!2>)(?!>>)(?!>>&)(?!&).)* {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

  /* Invalid character in input */
. {
  return NOTOKEN;
}

