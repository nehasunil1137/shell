
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>
#include <cstring>
#include <unistd.h>
#include <regex.h>
#include <dirent.h>
#include <algorithm>
#include <cassert>
#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT LESS NEWLINE GREATGREAT AMPERSAND GREATAMPERSAND GREATGREATAMPERSAND PIPE TWOGREAT

%{
//#define yylex yylex
#include <cstdio>
#include "shell.hh"
void expandWildcards(char*, char *);
static int myCompare(const void* , const void* );
void yyerror(const char * s);
int yylex();
void expandWildcardsIfNecessary(std::string  * );
std::vector<char *> _sortArgument = std::vector<char *>();
bool wildcard;
bool cmpfunction (char * i, char * j);
%}

%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

simple_command:	
  pipe_list iomodifier_list background NEWLINE {
   // printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE{
      //prompt???
  } 
  | error NEWLINE { yyerrok; }
  ;

pipe_list:
  command_and_args
  |pipe_list PIPE command_and_args
  ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
   // printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
    wildcard = false;
    char * p = (char*)"";
    expandWildcards(p, (char *)$1->c_str());
    //sort here?
    
    //Command::_currentSimpleCommand->insertArgument( $1 );
    std::sort(_sortArgument.begin(), _sortArgument.end(), cmpfunction);
    for (auto a: _sortArgument) {
      std::string * argToInsert = new std::string(a);
      Command::_currentSimpleCommand->insertArgument(argToInsert);
    }
    _sortArgument.clear();

 // expandWildcardsIfNecessary($1);
  }
  ;

command_word:
  WORD {
    if(strcmp($1->c_str(), "exit")==0 && isatty(0)){
      printf("BYEEE\n");
		  exit(1);
    }
   // printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

iomodifier_list:
  iomodifier
  |iomodifier_list iomodifier
  |
  ;

iomodifier:
  GREAT WORD {
//    printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._redirect++;
  }
  |LESS WORD {
  //  printf("   Yacc: insert input \"%s\"\n", $2->c_str());
    Shell::_currentCommand._inFile = $2;
  }
  |GREATGREAT WORD {
   // printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    //append then outfile
    Shell::_currentCommand._append = 1;
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._redirect++;
  }
  |GREATAMPERSAND WORD {
   // printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    //outfile and error file?
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
    Shell::_currentCommand._redirect++;
  }
  |GREATGREATAMPERSAND WORD {
   // printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    //append, outfile, and error file?
    Shell::_currentCommand._append = 1;
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
    Shell::_currentCommand._redirect++;
  }
  |TWOGREAT WORD {
   // printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._errFile = $2;
//    Shell::_currentCommand._redirect = Shell::_currentCommand._redirect + 1;
  } 
   /* can be empty */ 
  ;
  
background:
  AMPERSAND {
    Shell::_currentCommand._background = true;
  }
  |
  ;   
    

%%

bool cmpfunction (char * i, char * j) { return strcmp(i,j)<0; }

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

//wildcards
#define MAXFILENAME 1024
void expandWildcards(char * prefix, char * suffix){
  if(suffix[0] == 0){
    //suffix is empty, put prefix in argument
    if(!strchr(prefix, '*')){
      //char * temp;
      _sortArgument.push_back(strdup(prefix));
//      free(prefix);
    }
    return;
  } 
  
  char prefix_slash[MAXFILENAME];
  if(prefix[0] == 0){
    if(suffix[0] == '/'){
      suffix += 1; 
      sprintf(prefix_slash, "%s/", prefix);
    }else{
      strcpy(prefix_slash, prefix);
    }

  }else{
    sprintf(prefix_slash, "%s/", prefix);
  }

//obtain the next component in the suffix, advance suffix
  char * s = strchr(suffix, '/');
  char component[MAXFILENAME];
  if(s!=NULL){
    //copy up to the first /
    strncpy(component, suffix, s-suffix);
    component[s-suffix] = 0;
    suffix = s + 1;
  }
  else {
    //last part of the path, copy whole thing
    strcpy(component, suffix);
    suffix = suffix + strlen(suffix);
  }
  //need to expand component
  char newPrefix[MAXFILENAME];
  if(strchr(component, '*')==NULL){
    //component does not have wildcards
    if(prefix_slash[0] == 0){
      strcpy(newPrefix, component);
    }else{
      sprintf(newPrefix, "%s/%s", prefix, component);
    }
    expandWildcards(newPrefix, suffix);
    return;
    /*if (component[0] == 0){
      strcpy(newPrefix, component);
    }else{
      sprintf(newPrefix, "%s/%s", prefix, component);
      expandWildcards(newPrefix, suffix);
      return;
    }*/
  }
  
  //component contains wildcards
  //convert component to regex
  char * reg = (char *)malloc(2*strlen(component)+10);
  char * a = component;
  char * r = reg;
  *r = '^';
  r++;
  while(*a){
    if(*a == '*'){*r = '.'; r++; *r = '*'; r++;}
    else if(*a == '?'){*r='.'; r++;}
    else if(*a == '.'){*r = '\\'; r++; *r = '.'; r++;}
    else{*r=*a; r++;}
    a++;
  }
  *r = '$'; r++; *r = 0; //matching end of line and adding null char
  
  regex_t re;
  int expbuf = regcomp(&re, reg, REG_EXTENDED|REG_NOSUB);
  if(expbuf != 0){
    perror("compile");
    return;
  }
  char * dir;

  //if prefix is empty then list current directory
  if(prefix_slash[0] == 0){
    dir = (char *)".";
  }else{
    dir = prefix_slash;
  }
  
  DIR * d = opendir(dir);
  if (d == NULL){return;}
  
  struct dirent * ent;
  bool find = false;
  //need to check if entries match
  while((ent = readdir(d)) != NULL) {
    //check if name matches
    if(regexec(&re, ent->d_name, 1, NULL, 0)==0){
      find = true;
      if(prefix_slash[0] == 0){
        strcpy(newPrefix, ent->d_name);
      }else{
        sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
      }
      if(reg[1] == '.'){
        if (ent->d_name[0] != '.'){ 
        expandWildcards(newPrefix, suffix);
        }
          //expandWildcards(newPrefix, suffix);
     }else{
        expandWildcards(newPrefix, suffix);
     }
    }
  }
  if(!find){
    if(prefix_slash[0] == 0){
      strcpy(newPrefix, component);
    }else{
      sprintf(newPrefix, "%s/%s", prefix, component);
    }
    expandWildcards(newPrefix, suffix);
  }
  closedir(d);
  regfree(&re);
  free(reg);
}


/*
int maxEntries = 20;
int nEntries = 0;
char ** array = (char **) malloc(maxEntries*sizeof(char*));

void expandWildcardsIfNecessary(std::string * arg){
  if(strchr(arg->c_str(), '*') == NULL && strchr(arg->c_str(), '?') == NULL){
    Command::_currentSimpleCommand->insertArgument(arg);
    return;
  }
  char * a; 
  std::string path;

  DIR * dir;
  if (arg->c_str()[0] == '/') {
    std::size_t found = arg->find('/');
    while (arg->find('/',found+1) != -1) 
      found = arg->find('/', found+1);
      
    path = arg->substr(0, found+1);
    a = (char *)arg->substr(found+1, -1).c_str();
    dir = opendir(path.c_str());
    //printf("%s\n", path.c_str());
  }
  else {
    dir = opendir(".");
    a = (char *) arg;
  }
  if(dir == NULL){
     perror("opendir");
     return;
   }


  char * reg = (char *)malloc(2*strlen(arg->c_str())+10);
  //const char * a = arg->c_str();
  char * r = reg;
  *r = '^';
  r++;
  while(*a){
     if(*a == '*'){*r = '.'; r++; *r = '*'; r++;}
     else if(*a == '?'){*r='.'; r++;}
     else if(*a == '.'){*r = '\\'; r++; *r = '.'; r++;}
     else{*r=*a; r++;}
     a++;
   }
  *r = '$'; r++; *r = 0; //matching end of line and adding null char
  
  regex_t re;
  int expbuf = regcomp(&re, reg, REG_EXTENDED|REG_NOSUB);
  if(expbuf != 0){
     perror("compile");
     return;
   }
  
  struct dirent * ent;
  maxEntries = 20;
  nEntries = 0;
  array = (char **) malloc(maxEntries*sizeof(char*));

  while((ent = readdir(dir))!= NULL){
    if(regexec(&re, ent->d_name, 1, NULL, 0) == 0){
      if(nEntries == maxEntries){
        maxEntries *= 2;
        array = (char **) realloc(array, maxEntries*sizeof(char*));
        assert(array!=NULL);
      }
      if(ent->d_name[0] == '.'){
        if(arg->c_str()[0] == '.'){
          char * c_path = (char *) malloc(sizeof(char) * strlen(path.c_str()+1));
          strcpy(c_path, path.c_str());
          array[nEntries] = strdup(strcat(c_path,ent->d_name));
          nEntries++;

        }
      }else{
      char * c_path= (char *) malloc(sizeof(char) * strlen(path.c_str()+1));
      strcpy(c_path, path.c_str());
      array[nEntries] = strdup(strcat(c_path,ent->d_name));
      nEntries++;
      
      }
      
     // char * temp = strdup(ent->d_name);
     // std::string * temp2 = new std::string(temp);
     // Command::_currentSimpleCommand->insertArgument(temp2);
    }
  }
  
  closedir(dir);
  qsort(array, nEntries, sizeof(char*), cmpfunction);
  for(int i = 0; i < nEntries; i++){
    std::string * temp = new std::string(array[i]);
    Command::_currentSimpleCommand->insertArgument(temp);
  }
  free(array);
  regfree(&re);
}
*/








#if 0
main()
{
  yyparse();
}
#endif

