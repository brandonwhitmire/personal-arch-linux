/*
 * Loaded into the greeter only when a graphical user session already
 * exists. LightDM hands every greeter the boot autologin countdown, so
 * Switch User would sign back into that user after the timeout. Cancel
 * the countdown once the greeter has connected.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>

typedef int lightdm_bool;

lightdm_bool lightdm_greeter_connect_to_daemon_sync(void *greeter, void **error)
{
    static lightdm_bool (*real_connect)(void *, void **) = NULL;
    static void (*cancel_autologin)(void *) = NULL;

    if (!real_connect)
        real_connect = dlsym(RTLD_NEXT, "lightdm_greeter_connect_to_daemon_sync");
    if (!cancel_autologin)
        cancel_autologin = dlsym(RTLD_DEFAULT, "lightdm_greeter_cancel_autologin");

    lightdm_bool ok = real_connect(greeter, error);
    if (ok && cancel_autologin)
        cancel_autologin(greeter);
    return ok;
}
