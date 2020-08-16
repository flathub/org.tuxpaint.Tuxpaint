#!/usr/bin/python3
import sys
import enum
from gi.repository import GLib, Gio


PORTAL_BUS_NAME = "org.freedesktop.portal.Desktop"
PORTAL_OBJECT_PATH = "/org/freedesktop/portal/desktop"
REQUEST_IFACE = "org.freedesktop.portal.Request"
PRINT_PORTAL_IFACE = "org.freedesktop.portal.Print"
HANDLE_TOKEN = "lpr"


class PortalResponse(enum.Enum):
    SUCCESS = 0
    CANCELLED = 1
    OTHER = 2


def main():
    loop = GLib.MainLoop()
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)

    """
    Since version 0.9 of xdg-desktop-portal, the handle will be of the form
    /org/freedesktop/portal/desktop/request/SENDER/TOKEN, where SENDER is the
    callers unique name, with the initial ':' removed and all '.' replaced by
    '_', and TOKEN is a unique token that the caller provided with the
    handle_token key in the options vardict. 
    """
    unique_name = bus.props.unique_name
    sender = unique_name[1:].replace(".", "_")
    handle = f"{PORTAL_OBJECT_PATH}/request/{sender}/{HANDLE_TOKEN}"

    def response_cb(
        bus, sender_name, object_path, interface_name, signal_name, parameters
    ):
        if object_path != handle:
            return
        response, results = parameters
        if response == PortalResponse.OTHER:
            exit(1)
        # Success or user cancellation are both OK
        loop.quit()

    bus.signal_subscribe(
        PORTAL_BUS_NAME,
        REQUEST_IFACE,
        "Response",
        None,  # object_path,
        None,  # arg0,
        Gio.DBusSignalFlags.NO_MATCH_RULE,  # it's a directed signal, no match rule needed
        response_cb,
    )
    # TODO: lpr allows you to pass 1 or more paths as arguments. Support this.
    fd_list = Gio.UnixFDList.new_from_array([sys.stdin.fileno()])
    parent_window = ""  # No way to get its X11/Wayland ID
    title = ""  # TODO: base this on the application ID?
    fd = 0  # index into fd_list
    options = {
        "handle_token": GLib.Variant("s", HANDLE_TOKEN),
    }
    ret, _ = bus.call_with_unix_fd_list_sync(
        PORTAL_BUS_NAME,
        PORTAL_OBJECT_PATH,
        PRINT_PORTAL_IFACE,
        "Print",
        GLib.Variant("(ssha{sv})", (parent_window, title, fd, options,)),
        GLib.VariantType("(o)"),
        Gio.DBusCallFlags.NONE,
        -1,  # timeout,
        fd_list,
    )
    (handle,) = ret
    loop.run()


if __name__ == "__main__":
    main()
