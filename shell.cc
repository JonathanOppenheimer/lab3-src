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
  fprintf(stderr, "\nsig:%d      Ouch!\n", sig);
}

int main() {
  struct sigaction signalAction;
  signalAction.sa_handler = sigIntHandler;
  sigemptyset(&signalAction.sa_mask);
  signalAction.sa_flags = SA_RESTART;
  int error = sigaction(SIGINT, &signalAction, NULL);
  if (error) {
    perror("sigaction");
    exit(2);
  }

  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
