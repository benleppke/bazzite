#!/usr/bin/env python3
# custom-icon-name.py
#
# Nautilus extension to honor metadata::custom-icon-name by resolving it
# against the current icon theme and returning a Gio.ThemedIcon.
#
# Logs go to ~/.cache/nautilus-custom-icon.log

from gi.repository import Nautilus, GObject, Gio, Gtk, GLib
import logging
import os
import time

LOG_PATH = os.path.expanduser("~/.cache/nautilus-custom-icon.log")
os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)

logging.basicConfig(
    filename=LOG_PATH,
    level=logging.DEBUG,
    format="%(asctime)s %(levelname)s %(message)s",
)

# Simple TTL cache for resolved icons to avoid repeated query_info calls.
CACHE_TTL = 30.0  # seconds


class _IconCacheEntry:
    def __init__(self, themed_icon):
        self.icon = themed_icon
        self.ts = time.time()


class CustomIconNameProvider(GObject.GObject, Nautilus.IconProvider):
    def __init__(self):
        super().__init__()
        self._cache = {}  # map path -> _IconCacheEntry
        logging.debug("CustomIconNameProvider initialized")

    def _get_cached(self, path):
        ent = self._cache.get(path)
        if not ent:
            return None
        if time.time() - ent.ts > CACHE_TTL:
            logging.debug("Cache expired for %s", path)
            self._cache.pop(path, None)
            return None
        return ent.icon

    def _set_cache(self, path, themed_icon):
        self._cache[path] = _IconCacheEntry(themed_icon)
        logging.debug("Cached icon for %s -> %s", path, getattr(themed_icon, "names", themed_icon))

    def _read_custom_icon_name(self, gio_file):
        # Use Gio.File.query_info to read metadata::custom-icon-name
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
        # Check if the current theme has the icon
        try:
            theme = Gtk.IconTheme.get_default()
            if theme.has_icon(icon_name):
                logging.debug("Icon theme has icon: %s", icon_name)
                return Gio.ThemedIcon.new(icon_name)
            else:
                logging.debug("Icon theme does NOT have icon: %s", icon_name)
        except Exception as e:
            logging.exception("Error while checking icon theme for %s: %s", icon_name, e)
        return None

    # Nautilus.IconProvider API: get_icon(self, file)
    def get_icon(self, file):
        """
        Called by Nautilus when it wants an icon for a file.
        Return a Gio.Icon (e.g. Gio.ThemedIcon) or None.
        """
        # Only handle local files (file://)
        try:
            uri_scheme = file.get_uri_scheme()
        except Exception:
            logging.debug("file.get_uri_scheme() failed")
            return None

        if uri_scheme != "file":
            return None

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
            return None

        # return from cache if present
        cached = self._get_cached(path)
        if cached:
            return cached

        gio_file = Gio.File.new_for_path(path)

        # Read metadata
        icon_name = self._read_custom_icon_name(gio_file)
        if not icon_name:
            return None

        themed_icon = self._resolve_themed_icon(icon_name)
        if not themed_icon:
            # no such icon in current theme - don't override
            logging.debug("No themed icon resolved for %s on %s", icon_name, path)
            return None

        # cache and return
        self._set_cache(path, themed_icon)
        return themed_icon
