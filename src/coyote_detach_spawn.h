/*  coyote_detach_spawn.h — detached double-fork spawn for fire-and-forget
 *  child processes.  See coyote_detach_spawn.c for implementation details.
 *  Project: coyote */
#ifndef COYOTE_DETACH_SPAWN_H
#define COYOTE_DETACH_SPAWN_H

int coyote_detach_spawn(char *const argv[], const char *cwd);

#endif
