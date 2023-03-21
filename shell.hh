#ifndef shell_hh
#define shell_hh

#include "command.hh"
#include <vector>

extern int global_variable;

struct Shell {
  static void prompt();

  static Command _currentCommand;
};

#endif
