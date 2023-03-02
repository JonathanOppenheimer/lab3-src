
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

// Pipe 
"|" {
  return PIPE;
}

// Output redirection (stdout: 1 )
">" {
  return GREAT;
}

// Input redirection
"<" {
  return LESS;
}

// Output redirection (stderr : 2)
"2>" {
  return TWOGREAT
}

// Output redirection (stdout and stderr : 1 and 2)
">&" {
  return GREATAMPERSAND;
}

// Append output (stdout : 1)
">>" {
  return GREATGREAT;
}

// Append output (stdout and stderr : 1 and 2) 
">>&" {
  return GREATGREATAMPERSAND;
}

// Run process in background 
"&" {
  return AMPERSAND; 
}

[^ \t\n][^ \t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}