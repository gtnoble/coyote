/*  coyote_notify_c.c — small libnotify desktop-notification shim.
 *
 *  The shim keeps NotifyNotification and GError ownership on the C side.
 *  Notification calls are expected to originate from the GTK main task.
 *
 *  Project: coyote
 */

#include <libnotify/notify.h>
#include <glib-object.h>

static gboolean initialized = FALSE;
static gboolean init_attempted = FALSE;

int coyote_notify_show_completion (void)
{
    NotifyNotification *notification;
    GError *error = NULL;
    gboolean shown;

    if (!init_attempted) {
        init_attempted = TRUE;
        initialized = notify_init ("coyote");
    }

    if (!initialized)
        return 0;

    notification = notify_notification_new
      ("Coyote", "Agent turn complete.", NULL);
    if (notification == NULL)
        return 0;

    notify_notification_set_timeout (notification, 5000);
    notify_notification_set_urgency
      (notification, NOTIFY_URGENCY_NORMAL);
    notify_notification_set_app_name (notification, "coyote");
    shown = notify_notification_show (notification, &error);

    if (error != NULL)
        g_error_free (error);
    g_object_unref (notification);
    return shown ? 1 : 0;
}

void coyote_notify_finalize (void)
{
    if (initialized)
        notify_uninit ();

    initialized = FALSE;
    init_attempted = FALSE;
}
