/*  Detached double-fork spawn interface.
 *  Returns 0 when the intermediate child exits successfully and the status
 *  pipe closes without a reported setup/exec error.  Normally close-on-exec
 *  EOF indicates successful exec; unexpected grandchild death before exec
 *  is indistinguishable from that EOF.  The detached application's eventual
 *  exit status is not awaited or reported.
 */
#ifndef COYOTE_DETACH_SPAWN_H
#define COYOTE_DETACH_SPAWN_H

int coyote_detach_spawn(char *const argv[], const char *cwd);

#endif
