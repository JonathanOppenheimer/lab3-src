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
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "command.hh"
#include "shell.hh"

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
    Shell::prompt();
    return;
  }

  // Check for an error on the command line before execution
  if (!_errorFlag.empty()) {
    fprintf(stderr, "myshell: %s\n", _errorFlag.c_str());
  } else {
    // Print contents of Command data structure
    print();

    // Execute all the given simple commands
    int tmpin = dup(0);  // Temporary in file descriptor
    int tmpout = dup(1); // Tempory out file descriptor

    // Change initial input to the user provided input file
    int fdin;
    if (_inFile) {
      fdin = open(_inFile->c_str(), O_RDONLY);
    } else { // Use default input
      fdin = dup(tmpin);
    }

    int ret;   // fork(): 0 if child, > 0 if parent, < 0 if error
    int fdout; // The out file descriptor

    for (std::size_t i = 0, max = _simpleCommands.size(); i != max; ++i) {
      // Redirect input
      dup2(fdin, 0);
      close(fdin);

      // Setup the output based on the user on the last simple command
      if (i == _simpleCommands.size() - 1) {
        // Change final output to the user provided output file
        if (_outFile) {
          // Check if we need to append or simply edit the file
          if (_append) {
            fdout = open(_outFile->c_str(), O_APPEND | O_CREAT, 0644);
          } else {
            fdout = open(_outFile->c_str(), O_WRONLY | O_CREAT, 0644);
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

      // Create child process
      ret = fork();
      if (ret == 0) {
        // Conver the current command vector to a state suitable for execvp
        SimpleCommand *current_command = _simpleCommands.at(i);
        std::vector<std::string *> vector_args = current_command->_arguments;

        // Conver the arguement vector into an arg list
        std::vector<char *> argv(vector_args.size() + 1);

        // Copy pointers to each string's buffer into the new vector
        std::transform(vector_args.begin(), vector_args.end(), argv.begin(),
                       [](std::string *arg) { return arg->data(); });

        // Ensure the last member of the argv is NULL for execv
        argv.back() = nullptr;

        // Call execvp with modified arguements
        execvp(argv[0], argv.data());
        perror("execvp");
        exit(1);
      }
    } // for
      // restore in/out defaults
    dup2(tmpin, 0);
    dup2(tmpout, 1);
    close(tmpin);
    close(tmpout);

    if (!_background) {
      // Wait for last command
      waitpid(ret, NULL, 0);
    }
  }

  // Clear to prepare for next command
  clear();

  // Print new prompt
  Shell::prompt();
}

SimpleCommand *Command::_currentSimpleCommand;
