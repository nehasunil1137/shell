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

#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <iostream>
#include <sys/wait.h>
#include <cstring>
#include <fcntl.h>
#include <signal.h>
#include "command.hh"
#include "shell.hh"

int status = 0;
int backproc = 0;
std::vector<std::vector<std::string>> history = std::vector<std::vector<std::string>>();
int idx = 0;
Command::Command() {
  // Initialize a new vector of Simple Commands
  _simpleCommands = std::vector<SimpleCommand *>();
  _outFile = NULL;
  _inFile = NULL;
  _errFile = NULL;
  _background = false;
  _append = 0;
  _redirect = 0;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
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
  //    _history.clear();
  if(_outFile && _errFile && _outFile == _errFile){
    delete _outFile;
    _outFile = NULL;
    _errFile = NULL;

  }else{
    if ( _outFile ) {
      delete _outFile;
    }
    _outFile = NULL;
    if ( _errFile ) {
      delete _errFile;
    }
    _errFile = NULL;
  }

  if ( _inFile ) {
    delete _inFile;
  }
  _inFile = NULL;


  _background = false;
  _append = 0;
  _redirect = 0;
}

void Command::print() {
  printf("\n\n");
  printf("              COMMAND TABLE                \n");
  printf("\n");
  printf("  #   Simple Commands\n");
  printf("  --- ----------------------------------------------------------\n");

  int i = 0;
  // iterate over the simple commands and print them nicely
  for ( auto & simpleCommand : _simpleCommands ) {
    printf("  %-3d ", i++ );
    simpleCommand->print();
  }

  printf( "\n\n" );
  printf( "  Output       Input        Error        Background\n" );
  printf( "  ------------ ------------ ------------ ------------\n" );
  printf( "  %-12s %-12s %-12s %-12s\n",
      _outFile?_outFile->c_str():"default",
      _inFile?_inFile->c_str():"default",
      _errFile?_errFile->c_str():"default",
      _background?"YES":"NO");
  printf( "\n\n" );
}

void Command::execute() {
  // Don't do anything if there are no simple commands
  if ( _simpleCommands.size() == 0 ) {
    Shell::prompt();
    return;
  }
  if (_redirect > 1){
    fprintf(stderr, "Ambiguous output redirect.\n");
    //      fprintf(stderr, "val of redirect:%d ", _redirect);
    if(isatty(0)){Shell::prompt();}
    return;
  }
  //    chdir("test-shell");
  // Print contents of Command data structure
  // print();

  if(!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "setenv")){
    if(setenv(_simpleCommands[0]->_arguments[1]->c_str(), _simpleCommands[0]->_arguments[2]->c_str(), 1)){
      perror("setenv");
    }
    clear();
    if(isatty(0)){ Shell::prompt();}
    return;
  }else if(!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "unsetenv")){
    unsetenv(_simpleCommands[0]->_arguments[1]->c_str());
    clear();
    Shell::prompt();
    return;
  }else if(!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "cd")){
    if (_simpleCommands[0]->_arguments.size()==1) {
      chdir(getenv("HOME"));
    }else if(_simpleCommands[0]->_arguments[1]->c_str()[0] == '$'){
      chdir(getenv("HOME"));
    }else{
      const char * path = _simpleCommands[0]->_arguments[1]->c_str();
      int error =  chdir(path);
      if(error != 0){
        fprintf(stderr, "cd: can't cd to %s\n", _simpleCommands[0]->_arguments[1]->c_str());
        //dup2(fderr, 2);
      }
    }
    clear();
    if(isatty(0)){ Shell::prompt();}
    return;
  }

  //setting up file redirection
  //saving input, output, and error
  int tmpin = dup(0);
  int tmpout = dup(1);
  int tmperr = dup(2);
  //setting the initial input
  int fdin = 0;
  if(_inFile){
    //fdin = open(_inFile);
    fdin =  open(_inFile->c_str(), O_RDONLY);
  }else{
    //using the default input
    fdin=dup(tmpin);
  }
  //setting initial errorfile
  int fderr = 0;
  if(_errFile){
    if(_append==1){
      fderr = open(_errFile->c_str(), O_WRONLY|O_APPEND|O_CREAT, 0600);
    }else{
      fderr = open(_errFile->c_str(), O_WRONLY|O_CREAT|O_TRUNC, 0600);
    }
  }else{
    fderr = dup(tmperr);
  }
  int fdout = 0;
  dup2(fderr, 2);
  close(fderr);
  int pid;
  for (size_t i = 0; i < _simpleCommands.size(); i++){
    //calling builtin in parent
    // if (builtIn(i)){return;}
    //redirect input
    dup2(fdin, 0);
    close(fdin);
    //setup the output
    if(i == _simpleCommands.size()-1){
      //last simple command
      if(_outFile){
        if(_append == 1){
          fdout=open(_outFile->c_str(), O_WRONLY|O_APPEND|O_CREAT, 0600);
        }else{
          fdout=open(_outFile->c_str(), O_WRONLY|O_CREAT|O_TRUNC, 0600);
        }
      }else{
        //use the default output
        fdout=dup(tmpout);
        //fdout = open(_outFile->c_str(), O_WRONLY|O_CREAT|O_TRUNC, 0600);
      }
      if(_errFile){
        if(_append==1){
          fderr = open(_errFile->c_str(), O_WRONLY|O_APPEND|O_CREAT, 0600);
        }else{
          fderr = open(_errFile->c_str(), O_WRONLY|O_CREAT|O_TRUNC, 0600);
        }  
      }else{
        fderr = dup(tmperr);
      }
    }else{
      //not the last simple command, create pipe
      int fdpipe[2];
      pipe(fdpipe);
      fdout=fdpipe[1];
      fdin = fdpipe[0];
    }
    //redirect the output and close
    dup2(fdout,1);
    close(fdout);
    //redirect err and close
    //fork new child process
    pid = fork();
    if(pid == 0){
      //child process
      //convert the vector into const char *??
      /*if(builtInChild(i)){
        return;
        }*/
      if(!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "printenv")){
        char ** envvar = environ; 
        int i = 0;
        while (envvar[i] != NULL) {
          printf("%s\n", envvar[i]);
          i++;
        }
        clear();
        exit(0);
      }


      char ** commStr = new char*[_simpleCommands[i]->_arguments.size() +1];
      for (size_t j = 0; j < _simpleCommands[i]->_arguments.size(); j++) {
        //using function const_cast function to cast vector command to a c string
        commStr[j] = (const_cast<char*>(_simpleCommands[i]->_arguments[j]->c_str()));
        //adding the null terminating char to end of the string
        commStr[j][strlen(_simpleCommands[i]->_arguments[j]->c_str())] = '\0';

      }
      commStr[_simpleCommands[i]->_arguments.size()] = NULL;	
      execvp(commStr[0],commStr);
      //	perror("execvp");
      _exit(1);

    }
  }

  //close all inputs and outputs
  dup2(tmpin, 0);
  dup2(tmpout, 1);
  dup2(tmperr, 2);
  close(tmpin);
  close(tmpout);
  close(tmperr);
  close(fderr);
  int proc;
  //if background is false, wait for the last process to be over 
  if(_background == false){
    int stat;
    proc = waitpid(pid, &stat, 0);
    if(WIFEXITED(stat)){
      status = WEXITSTATUS(stat);
    }
  }else{
    backproc = pid;
  }

  //history pushing 
  history.resize(history.size()+1);
  for(int i = 0; i <_simpleCommands[0]->_arguments.size(); i++){
    history[idx].push_back(_simpleCommands[0]->_arguments[i]->c_str());
  }
  idx++;



  // Clear to prepare for next command
  clear();

  // Print new prompt
  if(isatty(0)){Shell::prompt();}
}

SimpleCommand * Command::_currentSimpleCommand;
