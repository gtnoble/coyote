#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>
static void drain(void) { while (gtk_events_pending()) gtk_main_iteration(); }
int main(int argc, char **argv) {
 gtk_init(&argc,&argv);
 GtkWidget *win=gtk_window_new(GTK_WINDOW_TOPLEVEL), *v=gtk_text_view_new();
 gtk_window_set_default_size(GTK_WINDOW(win),600,300);
 gtk_container_add(GTK_CONTAINER(win),v);
 gtk_text_view_set_pixels_above_lines(GTK_TEXT_VIEW(v),argc>1?atoi(argv[1]):2);
 gtk_text_view_set_pixels_below_lines(GTK_TEXT_VIEW(v),argc>2?atoi(argv[2]):2);
 GtkTextBuffer *b=gtk_text_view_get_buffer(GTK_TEXT_VIEW(v));
 gtk_text_buffer_set_text(b,"before $x$ after\nnext line\n",-1);
 GtkTextTag *tag=gtk_text_buffer_create_tag(b,NULL,"invisible",TRUE,NULL);
 GtkTextIter a,z; gtk_text_buffer_get_iter_at_offset(b,&a,7); gtk_text_buffer_get_iter_at_offset(b,&z,10);
 gtk_text_buffer_apply_tag(b,tag,&a,&z);
 GdkPixbuf *p=gdk_pixbuf_new(GDK_COLORSPACE_RGB,TRUE,8,12,12); gdk_pixbuf_fill(p,0xff0000ff);
 gtk_text_buffer_insert_pixbuf(b,&z,p); g_object_unref(p);
 gtk_widget_show_all(win); drain();
 for(int y=0;y<300;y++) for(int x=0;x<600;x++) {
  GtkTextIter it; int trailing;

  gtk_text_view_get_iter_at_position(GTK_TEXT_VIEW(v),&it,&trailing,x,y);
 }
 gtk_widget_destroy(win); drain(); return 0;
}
