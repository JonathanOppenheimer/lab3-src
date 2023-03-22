#ifndef shell_hh
#define shell_hh

#include "command.hh"

#include <set>
#include <vector>

extern void set_source();

/* Extra global variables for program to share information with */

extern bool source; // Used to track whether the command parsed was source
extern int last_return_code; // Return code of the last executed simple command
extern pid_t
    last_background_pid; // PID of the last process run in the background
extern std::string
    last_argument; // The last argument in the fully expanded previous command
extern std::string
    shell_location; // Used to store where the shell executable is
extern std::set<pid_t>
    background_pids; // Used to put the vectors of background processes into

/* ************************************************************ */

struct Shell {
  static void prompt();

  static Command _currentCommand;
};

#endif
