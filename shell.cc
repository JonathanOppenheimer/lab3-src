#include <cstdio>

#include <signal.h>
#include <unistd.h>

#include "shell.hh"

int yyparse(void);

void Shell::prompt() {
  if (isatty(0)) {
    printf("myshell>");
    fflush(stdout);
  }
}

extern "C" void sigIntHandler(int sig) {
  Shell::_currentCommand.clear();
  printf("\n");
  Shell::prompt();
}

extern "C" void sigChildHandler(int sig) { printf("hi"); }

int main() {
  /********* CTRL-C HANDLING **********/
  struct sigaction sigintSignalAction;
  sigintSignalAction.sa_handler = sigIntHandler;
  sigemptyset(&sigintSignalAction.sa_mask);
  sigintSignalAction.sa_flags = SA_RESTART;
  int intError = sigaction(SIGINT, &sigintSignalAction, NULL);
  if (intError) {
    perror("sigaction");
    exit(-1);
  }

  /* ******************************** */

  /********* Zombie Handling **********/

  struct sigaction sigchildSignalAction;
  sigchildSignalAction.sa_handler = sigChildHandler;
  sigemptyset(&sigchildSignalAction.sa_mask);
  sigchildSignalAction.sa_flags = SA_RESTART;
  int childError = sigaction(SIGCHLD, &sigchildSignalAction, NULL);
  if (childError) {
    perror("sigaction");
    exit(-1);
  }

  /* ******************************** */

  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
