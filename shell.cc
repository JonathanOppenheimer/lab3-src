#include <cstddef>
#include <cstdio>

#include <iostream>
#include <signal.h>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

#include "shell.hh"

int yyparse(void);

std::vector<pid_t> background_pids;

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

extern "C" void sigChildHandler(int sig) {
  // int pid = waitpid(-1, NULL, WNOHANG);
  // std::cout << pid;

  while (!background_pids.empty()) {
    pid_t pid = waitpid(background_pids.back(), NULL, 0);
    background_pids.pop_back();
    std::cout << std::to_string(pid) + " exited.";
  }
}

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
