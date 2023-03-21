#include <cstdio>
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>
#include "shell.hh"
#include "command.hh"
std::string p = "";
void yyrestart(FILE * file);
int yyparse(void);

void Shell::prompt() {
  if(isatty(0)){
    printf("myshell>");
    fflush(stdout);
  }
  fflush(stdout);
}
//ctrl C
extern "C" void ctrlC(int sig){
  printf("\n");
  if(isatty(0)){
  
    Shell::prompt();
  }
 // Shell::prompt();
}

//zombie processes
extern "C" void zombie(int sig){
//  int pid = waitpid(-1,0,0);
 // printf("[%d] exited.\n", pid);
  while(waitpid(-1, NULL, WNOHANG)>0) {}
}

int main(int argc, char * argv[]) {
  p = argv[0];
  //ctrl C sigaction
  struct sigaction sigCtrl;
  sigCtrl.sa_handler = ctrlC;
  sigemptyset(&sigCtrl.sa_mask);
  sigCtrl.sa_flags = SA_RESTART;
  int error = sigaction(SIGINT, &sigCtrl, NULL);  
  if(error){
    perror("sigaction");
    exit(-1);
  }
  //zombie processes sigaction
//  if(Shell::_currentCommand._background == true){
    struct sigaction sigZombie;
		sigZombie.sa_handler = zombie;
		sigemptyset(&sigZombie.sa_mask);
		sigZombie.sa_flags = SA_RESTART;
    int error2 = sigaction(SIGCHLD, &sigZombie, NULL);
		if (error2) {
			perror("sigaction");
			exit(-1);
		}
 // }
  
  if (isatty(0)) {
	Shell::prompt();
  }
  yyparse();
}

Command Shell::_currentCommand;
