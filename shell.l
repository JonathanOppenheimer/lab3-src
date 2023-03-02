
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include "y.tab.hh"

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

"|" {
  return PIPE;
}

">" {
  return GREAT;
}

"<" {
  return LESS;
}

"2>" {
  return TWOGREAT;
}

">&" {
  return GREATAMPERSAND;
}

">>" {
  return GREATGREAT;
}

">>&" {
  return GREATGREATAMPERSAND;
}

"&" {
  return AMPERSAND; 
}

[^ \t\n][^ \t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}

