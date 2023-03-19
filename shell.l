/*
 *
 * CS-252
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{
#include <algorithm>
#include <boost/algorithm/string.hpp>
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
    boost::trim(buffer);
    yylval.cpp_string = new std::string(buffer);
    return WORD;
  }

  \n {
    buffer += yytext;
    /* Keep prompting for input */
    std::cout << "> ";
  }

  \\(.|\n) {
    buffer += yytext[1];
  }

  [^ \\"\n]* {
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

  /* Match the majority of normal strings */
[^ \n\t]* {
    /* Set up the strings for use */
    buffer.clear();
    buffer += yytext;
    std::string trimmed;

    /* Parse the string for escaped characters and '"'. Deal with quotes.
     * In the case of an unclose '"', start the action to prompt the user 
     * to close it.
     */
    for(size_t i = 0; i < buffer.size(); ++i) {
      if(buffer[i] == '"') {
        int next_quote = buffer.find('"', i+1);
        if(next_quote == std::string::npos && buffer[next_quote - 1] != '\\') {
          buffer.erase(i,1);
          trimmed.clear();
          yy_push_state(quotes);
          break;
        } else {
          buffer.erase(i, 1); /* Delete the trailing " */
          buffer.erase(next_quote-1, 1); /* Delete the trailing " */
        }
      }

      /* Trims escaped characters */
      if(buffer[i] == '\\') {
        trimmed += buffer[i+1];
        i += 1;
      } else {
        trimmed += buffer[i];
      }
    }
    
    boost::trim(trimmed);
    yylval.cpp_string = new std::string(trimmed);
    return WORD;
  }

  /* Invalid character in input */
. {
  return NOTOKEN;
}

