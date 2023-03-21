/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <algorithm>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <iostream>

#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "command.hh"
#include "shell.hh"

extern char **environ; // System global var inherited from parent

Command::Command() {
  // Initialize a new vector of Simple Commands
  _simpleCommands = std::vector<SimpleCommand *>();

  _outFile = NULL;
  _inFile = NULL;
  _errFile = NULL;
  _append = false;
  _background = false;
}

void Command::insertSimpleCommand(SimpleCommand *simpleCommand) {
  // add the simple command to the vector
  _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
  // deallocate all the simple commands in the command vector
  for (auto simpleCommand : _simpleCommands) {
    delete simpleCommand;
  }

  // remove all references to the simple commands we've deallocated
  // (basically just sets the size to 0)
  _simpleCommands.clear();

  // Check if the out and err are the same. We only need to delete once.
  if (_outFile == _errFile) {
    delete _outFile;
    _outFile = NULL;
    _errFile = NULL;
  } else { // Otherwise delete them individually
    if (_outFile) {
      delete _outFile;
    }
    _outFile = NULL;

    if (_errFile) {
      delete _errFile;
    }
    _errFile = NULL;
  }

  if (_inFile) {
    delete _inFile;
  }
  _inFile = NULL;

  _append = false;

  _background = false;

  _errorFlag.clear();
}

void Command::print() {
  printf("\n\n");
  printf("              COMMAND TABLE                \n");
  printf("\n");
  printf("  #   Simple Commands\n");
  printf("  --- ----------------------------------------------------------\n");

  int i = 0;
  // iterate over the simple commands and print them nicely
  for (auto &simpleCommand : _simpleCommands) {
    printf("  %-3d ", i++);
    simpleCommand->print();
  }

  printf("\n\n");
  printf("  Output       Input        Error        Background   Append \n");
  printf(
      "  ------------ ------------ ------------ ------------ ------------\n");
  printf("  %-12s %-12s %-12s %-12s %-12s\n",
         _outFile ? _outFile->c_str() : "default",
         _inFile ? _inFile->c_str() : "default",
         _errFile ? _errFile->c_str() : "default", _background ? "YES" : "NO",
         _append ? "true" : "false");

  printf("\n\n");
}

void Command::execute() {
  // Don't do anything if there are no simple commands
  if (_simpleCommands.size() == 0) {
    Shell::prompt(); // Reprompt
    return;
  }

  /* Used to check how the child processes return (e.g. if the child terminated
   * normally, that is, by calling exit(3) or _exit(2), or by returning from
   * main()
   */
  int status;

  // Check for an error on the command line before execution
  if (!_errorFlag.empty()) {
    fprintf(stderr, "%s\n", _errorFlag.c_str());
  } else {
    // Print contents of Command data structure
    // print(); (Needed for grading)

    // Execute all the given simple commands
    int tmpin = dup(0);  // Temporary in file descriptor
    int tmpout = dup(1); // Tempory out file descriptor
    int tmperr = dup(2); // Temporary error file descriptor

    // Change initial input to the user provided input file
    int fdin;
    if (_inFile) {
      fdin = open(_inFile->c_str(), O_RDONLY);
    } else { // Use default input
      fdin = dup(tmpin);
    }
    // Input will be redirected within the for loop

    // Change error output to the user provided error file
    int fderr;
    if (_errFile) {
      // See whether error should be appended or written
      if (_append) {
        fderr = open(_errFile->c_str(), O_CREAT | O_WRONLY | O_APPEND, 0644);
      } else {
        fderr = open(_errFile->c_str(), O_CREAT | O_WRONLY | O_TRUNC, 0644);
      }
    } else { // Use default error
      fderr = dup(tmperr);
    }
    // Redirect error
    dup2(fderr, 2);
    close(fderr);

    int ret;   // fork(): 0 if child, > 0 if parent, < 0 if error
    int fdout; // The out file descriptor

    for (std::size_t i = 0, max = _simpleCommands.size(); i != max; ++i) {
      // Used to maintain whether the command is built-in or executed
      bool builtin_cmd = false;

      // Redirect input
      dup2(fdin, 0);
      close(fdin);

      // Setup the output based on the user on the last simple command
      if (i == _simpleCommands.size() - 1) {
        // Change final output to the user provided output file
        if (_outFile) {
          // Check if we need to append or simply edit the file
          if (_append) {
            fdout =
                open(_outFile->c_str(), O_CREAT | O_WRONLY | O_APPEND, 0644);
          } else {
            fdout = open(_outFile->c_str(), O_CREAT | O_WRONLY | O_TRUNC, 0644);
          }
        } else { // Otherwise, use default output
          fdout = dup(tmpout);
        }
      } else { // Not last command - pipe output to next command
        // Create the pipe
        int fdpipe[2];
        pipe(fdpipe);
        fdout = fdpipe[1];
        fdin = fdpipe[0];
      }

      // Redirect output
      dup2(fdout, 1);
      close(fdout);

      // Convert the current command vector to a state suitable for execvp
      SimpleCommand *current_command = _simpleCommands.at(i);
      std::vector<std::string *> vector_args = current_command->_arguments;

      // Conver the arguement vector into an arg list
      std::vector<char *> argv(vector_args.size() + 1);

      // Copy pointers to each string's buffer into the new vector
      std::transform(vector_args.begin(), vector_args.end(), argv.begin(),
                     [](std::string *arg) { return arg->data(); });

      // Ensure the last member of the argv is NULL for execv
      argv.back() = nullptr;

      /* Specific commands that must be run in the parent */

      // Set environment variable
      if (!strcmp(argv[0], "setenv")) {
        builtin_cmd = true;
        if (setenv(argv[1], argv[2], 1)) {
          perror("setenv");
        }
      }

      // Unset environment variable
      if (!strcmp(argv[0], "unsetenv")) {
        builtin_cmd = true;
        if (unsetenv(argv[1])) {
          perror("unsetenv");
        }
      }

      // Change directory
      if (!strcmp(argv[0], "cd")) {
        builtin_cmd = true;

        // No argument provided, default to home directory
        if (argv[1] == nullptr) {
          if (chdir(getenv("HOME"))) {
            perror("can't cd to");
          }
        } else { // Otherwise go to provided directory
          if (chdir(argv[1])) {
            perror("can't cd to");
          }
        }
      }

      /* ************************************************ */

      // Create child process if required (non-built in functions)
      if (!builtin_cmd) {
        ret = fork();
        if (ret == 0) {
          // Do a special check for printenv
          if (!strcmp(argv[0], "printenv")) {
            char **p = environ;
            while (*p != NULL) {
              printf("%s\n", *p);
              p++;
            }
            exit(0);
          }

          // Call execvp with modified arguements for all other commands
          execvp(argv[0], argv.data());
          perror("execvp");
          _exit(1);
        } else if (ret < 0) {
          // There was an error in fork
          perror("fork");
          exit(2);
        }
      }
    }

    // Restore input, output, and error defaults
    dup2(tmpin, 0);
    dup2(tmpout, 1);
    dup2(tmperr, 2);

    // Close file descriptors that are not needed
    close(tmpin);
    close(tmpout);
    close(tmperr);

    if (!_background) {
      // Wait for last command
      waitpid(ret, &status, 0);
    } else {
      background_pids.push_back(ret);
      // zombie_processes.push_back(ret);
    }
  }

  // Clear to prepare for next command
  clear();

  // Print new prompt if the child process exited normally
  if (WIFEXITED(status) && !source) {
    Shell::prompt();
  }
}

SimpleCommand *Command::_currentSimpleCommand;
