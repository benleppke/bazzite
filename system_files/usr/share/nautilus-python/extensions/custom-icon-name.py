#!/usr/bin/env python3
# custom-icon-name.py
#
# Nautilus extension to honor metadata::custom-icon-name by resolving it
# against the current icon theme and returning a Gio.ThemedIcon.
#
# Logs write to ~/.cache/nautilus-custom-icon.log

import os
import logging
from logging.handlers import RotatingFileHandler
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Nautilus', '4.0')
from gi.repository import Nautilus, GObject, Gio, Gtk, Gdk, GLib

log_path = os.path.expanduser("~/.cache/nautilus-custom-icon.log")
os.makedirs(os.path.dirname(log_path), exist_ok=True)

handler = RotatingFileHandler(log_path, maxBytes=5*1024*1024, backupCount=1)
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
handler.setFormatter(formatter)

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
logger.addHandler(handler)

cache_ttl = 30.0  # seconds

class _IconCacheEntry:
    def __init__(self, themed_icon):
        self.icon = themed_icon
        self.ts = time.time()

class CustomIconNameProvider(GObject.GObject, Nautilus.InfoProvider):
    def __init__(self):
        super().__init__()
        self._cache = {}
        # logging.debug(f"Nautilus Custom Icon Name initialized (extension path: {__file__})")

    def _get_cached(self, path):
        ent = self._cache.get(path)
        if not ent:
            return None
        if time.time() - ent.ts > cache_ttl:
            logging.debug("Cache expired for %s", path)
            self._cache.pop(path, None)
            return None
        return ent.icon

    def _set_cache(self, path, themed_icon):
        self._cache[path] = _IconCacheEntry(themed_icon)
        logging.debug("Cached icon for %s -> %s", path, getattr(themed_icon, "names", themed_icon))

    def _read_custom_icon_name(self, gio_file):\
        # use Gio.File.query_info to read metadata::custom-icon-name
        try:
            info = gio_file.query_info(
                "metadata::custom-icon-name",
                Gio.FileQueryInfoFlags.NONE,
                None,
            )
        except Exception as e:
            logging.debug("query_info failed for %s: %s", gio_file.get_path(), e)
            return None

        try:
            name = info.get_attribute_string("metadata::custom-icon-name")
        except Exception as e:
            logging.debug("get_attribute_string failed: %s", e)
            return None

        if name:
            name = name.strip()
            logging.debug("Found metadata::custom-icon-name for %s: %s", gio_file.get_path(), name)
            return name
        return None

    def _resolve_themed_icon(self, icon_name):
        # check if the current theme has the icon
        try:
            display = Gdk.Display.get_default()
            theme = Gtk.IconTheme.get_for_display(display)

            size = 48
            scale = 1
            direction = Gtk.TextDirection.LTR
            flags = 0

            icon_obj = theme.lookup_icon(icon_name, None, size, scale, direction, flags)
            if icon_obj:
                logging.debug(f"Icon '{icon_name}' found in current icon theme.")
                return Gio.ThemedIcon.new(icon_name)
            else:
                logging.debug(f"Icon '{icon_name}' NOT found in current icon theme.")

        except Exception as e:
            logging.error(f"Error looking up icon {icon_name}: {e}")
        return None

    def update_file_info(self, file):
        try:
            uri_scheme = file.get_uri_scheme()
        except Exception:
            logging.debug("file.get_uri_scheme() failed")
            return

        if uri_scheme != "file":
            return

        path = None
        try:
            loc = file.get_location()
            if loc:
                path = loc.get_path()
        except Exception:
            logging.debug("file.get_location() failed; falling back to file.get_uri()")
            try:
                path = GLib.filename_from_uri(file.get_uri())[0]
            except Exception:
                path = None

        if not path:
            return

        # return from cache if present
        cached = self._get_cached(path)
        if cached:
            file.set_icon(cached)
            return

        gio_file = Gio.File.new_for_path(path)

        # read metadata
        icon_name = self._read_custom_icon_name(gio_file)
        if not icon_name:
            return

        themed_icon = self._resolve_themed_icon(icon_name)
        if not themed_icon:
            # no such icon in current theme - don't override
            logging.debug("No themed icon resolved for %s on %s", icon_name, path)
            return

        # cache and return
        self._set_cache(path, themed_icon)
        file.set_icon(themed_icon)
