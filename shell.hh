#ifndef shell_hh
#define shell_hh

#include "command.hh"

struct Shell {
  static void prompt();

  static Command _currentCommand;

  static std::vector<int> zombie_processes;
};

#endif
