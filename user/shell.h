#ifndef __SHELL_H
#define __SHELL_H

int shell_addchar(int ch);
char* shell_readline(const char *prompt);
void shell_freeline(char *line);

#endif
