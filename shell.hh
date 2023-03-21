#ifndef shell_hh
#define shell_hh

#include "command.hh"

extern std::vector<int> zombie_processes;

struct Shell {
  static void prompt();

  static Command _currentCommand;
};

#endif
