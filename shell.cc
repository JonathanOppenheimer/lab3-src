#include <cstddef>
#include <cstdio>
#include <iostream>
#include <string>
#include <vector>

#include <bits/stdc++.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

#include "shell.hh"

int yyparse(void);

std::set<pid_t> background_pids;
std::string shell_location;

void Shell::prompt() {
  if (isatty(0) && !source) {
    printf("myshell>");
  }
  fflush(stdout);
}

extern "C" void sigIntHandler(int sig) {
  Shell::_currentCommand.clear();
  printf("\n");
  Shell::prompt();
}

extern "C" void sigChildHandler(int sig) {
  // Need to empty out all the background processes
  pid_t pid; // pid to check
  while ((pid = waitpid(-1, NULL, WNOHANG)) > 0) {
    if (background_pids.count(pid) == 1) {
      std::cout << std::to_string(pid) + " exited.\n";
      background_pids.erase(pid);
    }
  }
}

int main(int argc, char *argv[]) {
  // Get the location of ./shell
  shell_location = std::string(realpath(argv[0], NULL));

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

  set_source();    // run source on boot (can modify path here)
  Shell::prompt(); // First prompt
  yyparse();       // Start parse
}

Command Shell::_currentCommand;
