#ifndef command_hh
#define command_hh

#include "simpleCommand.hh"

// Command Data Structure
extern int status;
extern int backproc;
extern std::string p;
extern std::vector<std::vector<std::string >> _history;
struct Command {
  std::vector<SimpleCommand *> _simpleCommands;
  std::string * _outFile;
  std::string * _inFile;
  std::string * _errFile;
  bool _background;
  int _append;
  int _redirect;
  


  Command();
  void insertSimpleCommand( SimpleCommand * simpleCommand );

  void clear();
  void print();
  void execute();
  bool builtIn(int i);
  bool builtInChild(int i);
  static SimpleCommand *_currentSimpleCommand;
};

#endif
