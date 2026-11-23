#ifndef COYOTE_CANVAS_TILES_H
#define COYOTE_CANVAS_TILES_H

#include <stddef.h>
#include <stdint.h>

#define COYOTE_CANVAS_TILE_SIDE 256U
#define COYOTE_CANVAS_TILE_MAX_SIDE 32768U

enum coyote_canvas_tile_result {
   COYOTE_TILE_OK = 0,
   COYOTE_TILE_INVALID,
   COYOTE_TILE_UNSUPPORTED,
   COYOTE_TILE_LIMIT,
   COYOTE_TILE_IO,
   COYOTE_TILE_CANCELLED,
   COYOTE_TILE_MEMORY
};

typedef int (*coyote_canvas_tile_cancel)(void *);

struct coyote_canvas_tile_info {
   uint32_t width, height;
};

/* Caller owns both descriptors. Source must be a regular file; staging
 * must be an empty private regular file opened O_RDWR, without O_APPEND.
 * Positions are unchanged. On failure staging is truncated back to zero
 * (failure to roll back is an I/O error; always discard failed staging).
 * max_bytes includes the header. The callback returns nonzero to cancel.
 * Success does not publish or sync the file: that is the store's job. */
int coyote_canvas_tiles_import(int source_fd, int staging_fd,
                              uint64_t max_bytes,
                              coyote_canvas_tile_cancel cancel, void *user,
                              struct coyote_canvas_tile_info *info);

/* Validate the version, extents and exact length, not pixel integrity.
 * A published asset must additionally be verified by the session store. */
int coyote_canvas_tiles_inspect(int fd, struct coyote_canvas_tile_info *info);

/* Read a zero-based tile into caller-owned storage as packed straight RGBA.
 * Edge tiles return their actual size and contain no padding. */
int coyote_canvas_tiles_read(int fd, uint32_t tile_x, uint32_t tile_y,
                            unsigned char *rgba, size_t capacity,
                            struct coyote_canvas_tile_info *extent);

/* Reduce a checked v1 straight-RGBA asset by a 2x alpha-weighted box filter.
 * Staging must be an empty private O_RDWR regular file without O_APPEND.
 * On failure, staging is truncated to zero. Descriptor offsets are preserved. */
int coyote_canvas_tiles_reduce(int source_fd, int staging_fd,
                              coyote_canvas_tile_cancel cancel, void *user);

/* Create an unlinked private staging file opened for read/write, or return -1. */
int coyote_canvas_tiles_stage(void);

/* Internal decoder boundary. Restore rows for later interlace passes. */
struct coyote_canvas_tile_writer;
int coyote_canvas_tiles_begin(struct coyote_canvas_tile_writer *,
                             uint32_t width, uint32_t height);
int coyote_canvas_tiles_row(struct coyote_canvas_tile_writer *,
                           uint32_t y, unsigned char *rgba, int write_row);
int coyote_canvas_tiles_cancelled(const struct coyote_canvas_tile_writer *);
int coyote_canvas_tiles_decode(int source_fd, struct coyote_canvas_tile_writer *);

#endif
