#include <cmark-gfm.h>

static int node_frees;
static int iter_frees;
static int last_free;
static int free_sequence;
static int fail_parser;
static int fail_iterator;

extern void __real_cmark_node_free(cmark_node *node);
extern void __real_cmark_iter_free(cmark_iter *iter);
extern cmark_parser *__real_cmark_parser_new(int options);
extern cmark_iter *__real_cmark_iter_new(cmark_node *root);

void __wrap_cmark_node_free(cmark_node *node)
{
    if (node != NULL) {
        ++node_frees;
        last_free = 1;
        free_sequence = free_sequence * 10 + 1;
    }
    __real_cmark_node_free(node);
}

void __wrap_cmark_iter_free(cmark_iter *iter)
{
    if (iter != NULL) {
        ++iter_frees;
        last_free = 2;
        free_sequence = free_sequence * 10 + 2;
    }
    __real_cmark_iter_free(iter);
}

cmark_parser *__wrap_cmark_parser_new(int options)
{
    if (fail_parser) {
        fail_parser = 0;
        return NULL;
    }
    return __real_cmark_parser_new(options);
}

cmark_iter *__wrap_cmark_iter_new(cmark_node *root)
{
    if (fail_iterator) {
        fail_iterator = 0;
        return NULL;
    }
    return __real_cmark_iter_new(root);
}

void cmark_probe_reset(void)
{
    node_frees = 0;
    iter_frees = 0;
    last_free = 0;
    free_sequence = 0;
    fail_parser = 0;
    fail_iterator = 0;
}

int cmark_probe_node_frees(void) { return node_frees; }
int cmark_probe_iter_frees(void) { return iter_frees; }
int cmark_probe_last_free(void) { return last_free; }
int cmark_probe_free_sequence(void) { return free_sequence; }
void cmark_probe_fail_parser(void) { fail_parser = 1; }
void cmark_probe_fail_iterator(void) { fail_iterator = 1; }
