
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include "y.tab.hh"
#include <sys/wait.h>
static  void yyunput (int c,char *buf_ptr  );
#include "command.hh"
extern int status;
extern int backproc;
extern std::string p;
extern std::vector<std::vector<std::string>> history; 
void myunputc(int c) {
  unput(c);
}
#include <string.h>
//#include "y.tab.hh"
extern "C" char * read_line();

int mygetc(FILE * f){
    static char *p;
    char ch;
    if(!isatty(0)){
      return getc(f);
    }
    if(p==NULL || *p==0){
      char *s = read_line();
      p = s;
    }

    ch = *p;
    p++;

    return ch;
}

#undef getc
#define getc(f) mygetc(f)





%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">" {
  return GREAT;
}

">>" {
  return GREATGREAT;
}

"<" {
  return LESS;
}

"|" {
  return PIPE;
}

"&" {
  return AMPERSAND;
}

"" {
  return NOTOKEN;
}

">&" {
  return GREATAMPERSAND;
}

">>&" {
  return GREATGREATAMPERSAND;
}

"2>" {
  return TWOGREAT;
}

source[ ][^ \n\t]* { /*source builtin command*/
  std::string cmd = std::string(yytext);
  cmd = cmd.erase(0,7);
  //fprintf(stderr,"%s\n",cmd.c_str());
  yyin = fopen(cmd.c_str(), "r");
  yypush_buffer_state(yy_create_buffer( yyin, YY_BUF_SIZE ));
  BEGIN(INITIAL);
}
<<EOF>> {
	yypop_buffer_state();
  
  if ( !YY_CURRENT_BUFFER ) {
    yyterminate();
  } 
}


~[^ \n\t]* {
  std::string str = std::string(yytext);
  std::string home = getenv("HOME");
  if(str.size() == 1) {
    yylval.cpp_string = new std::string(home);
  }else{
    if(str[1] == '/') {
      str = home + str.substr(1,-1);
    }else{
      str = std::string("/homes/") +str.substr(1,-1);
    }
    yylval.cpp_string = new std::string(str);
  }
  return WORD;
}

\$\{\$\} {
 //  fprintf(stdout, "val: %s\n", cmd.c_str());
   int  result = getpid();
   char  buff[100];
   sprintf(buff,"%d", result);
   yylval.cpp_string =  new std::string(buff);
   return WORD;
}

\$\{\?\} {
  char buf[100];
  sprintf(buf,"%d", status);
  yylval.cpp_string = new std::string(buf);
  return WORD;
}

\$\{\!\} {
//PID of last processes running in background
  char buff[100];
  sprintf(buff, "%d", backproc);
  yylval.cpp_string = new std::string(buff);
  return WORD;
}

\$\{\_\} {
//the last argument in the fully expanded previous command
  int a = 0;
  int b = history.at(a).size()-1;
  std::string lastComm = history.at(a).at(b);
  yylval.cpp_string = new std::string(lastComm);
  return WORD;
}


([^\n\t ]([${][^ \n\t\}]*[}])[^ \n\t ]*)* {
  std::string y = std::string(yytext);
  std::string str1 = "";
  std::string str2 = "";
  for(int i = 0; i < y.size(); i++){
    if(y[i] == '$'){
      if(y[i+1] == '{'){
        i = i+2;
        while(y[i] != '}'){
          str2.append(y, i, 1);
          i++;
        }
        //printf("val %s\n",str2.c_str());
        if(strcmp(str2.c_str(), "SHELL") == 0){
          char buff[100];
          char * pat = realpath(p.c_str(),buff);
//          printf("path: %s\n", pat);
          yylval.cpp_string = new std::string(pat);
          return WORD;
        }
        char * path = getenv(str2.c_str());
        //sleep(1);
        str1.append(path);
        str2.erase();

      }
      //str1[i] = y[i];
    }else{
      str1.append(y,i,1);
    }
  }
//  str1[str1.size()-1] = y[y.size()-1];
  yylval.cpp_string = new std::string(str1);
  return WORD;
}

[`][^\n`]*[`]|\$\([^\n]*\) { /*regex for subshells*/
  //parse: remove $()
  std::string cmdstr = std::string(yytext);
  if(cmdstr[0] == '$'){
    //handle $()
    cmdstr = cmdstr.substr(2,cmdstr.size()-3);
    cmdstr.append("\nexit\n");

  }

//char *cmd = const_cast<char*> (cmdstr.c_str());
  int tmpin = dup(0);
  int tmpout = dup(1);
  //create 2 pipes, pipeIn and pipeOut
  int pipeIn[2];
  pipe(pipeIn);
  int pipeOut[2];
  pipe(pipeOut);
  
  dup2(pipeIn[0], 0);
  dup2(pipeOut[1], 1);
  close(pipeIn[0]);
  close(pipeOut[1]);
  
  write(pipeIn[1], cmdstr.c_str(), cmdstr.size());
  close(pipeIn[1]);
  //create child process
  int pid = fork();
  //redirecting input and output
  if(pid == 0){
    //call execvp to run command from subshell?
    char ** list = new char*[2];
    list[0] =(char*) "/proc/self/exe";
    list[1] = NULL;
    execvp(list[0], list);
//    exit(1);
  }
  waitpid(pid, NULL, 0);
  dup2(tmpin, 0);
	dup2(tmpout, 1);
	close(tmpin);
	close(tmpout);  
  //read from pipeOut[0] and writes to buffer
  char* buffer = new char[4096];
  int r = read(pipeOut[0], buffer, 4096);
  for(int j = r-1; j >= 0; --j) {	
		 if (buffer[j] == '\n') {  //if \n then put a space
       buffer[j] = '\t';
     }
    myunputc(buffer[j]);
	}
  close(pipeOut[0]);
  delete buffer;
}

["][^\n"]*["]  { /*quotations*/
  std::string cmd (yytext);
  yylval.cpp_string = new std::string(cmd.substr(1,cmd.length()-2));
  return WORD;
}


[^ \t\n|.]*\\[^ \t\n]* { /*escape seq*/
  char * str = strdup(yytext); //saving command
	char * newstr = (char*) malloc (100);//allocating space for new parsed command

	int i = 0;
	while (*str){//using pointer to traverse through command
		if (*str == '\\'){
			if (*(str+1) == '\\'){
				str = str +2;
				newstr[i] = '\\';
			}else{
				newstr[i] = *(++str);
			}
		}else{
			newstr[i] = *str;
		}
		str++;
    i++;
	}
	newstr[i] = '\0';

  yylval.cpp_string = new std::string(newstr);
	return WORD;
}

[^ \|>\t\n][^ \|>\t\n]*  {
  /* Assume that file names have only alpha chars */
   yylval.cpp_string = new std::string(yytext);
   return WORD;
}

