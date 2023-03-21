#ifndef shell_hh
#define shell_hh

#include "command.hh"
#include <vector>

extern std::vector<pid_t>
    background_pids; // Used to put the vectors of background processes into
extern std::string
    shell_location; // Used to store where the shell executable is
extern bool source; // Used to track whether the command parsed was source

struct Shell {
  static void prompt();

  static Command _currentCommand;
};

#endif
