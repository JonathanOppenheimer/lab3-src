#ifndef shell_hh
#define shell_hh

#include "command.hh"
#include <vector>

extern std::vector<pid_t> background_pids;

struct Shell {
  static void prompt();

  static Command _currentCommand;
};

#endif
