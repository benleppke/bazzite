#!/usr/bin/env python3
# custom-icon-name.py
#
# Nautilus extension to honor metadata::custom-icon-name by resolving it
# against the current icon theme and returning a Gio.ThemedIcon.
#
# Logs write to ~/.cache/nautilus-custom-icon.log

import os
import time
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
    _cache = {}

    def __init__(self):
        super().__init__()
        logging.debug(f"Extension initialized: {__file__})")

    def _get_cached(self, path):
        ent = self._cache.get(path)
        if not ent:
            logging.debug(f"No cached icon available for {path}, checking theme...")
            return None
        if time.time() - ent.ts > cache_ttl:
            logging.debug(f"Cached icon expired for {path}, removing entry from cache")
            self._cache.pop(path, None)
            return None
        logging.debug(f"Cached icon for {path} found, returning icon from cache")
        return ent.icon

    def _set_cache(self, path, themed_icon):
        icon_names = themed_icon.get_names() if hasattr(themed_icon, "get_names") else []
        icon_name = icon_names[0] if icon_names else None
        logging.debug(f"Caching '{icon_name}' for {path}")
        self._cache[path] = _IconCacheEntry(themed_icon)

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
            logging.debug("Custom icon metadata found for %s, '%s' icon requested", gio_file.get_path(), name)
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
                logging.debug(f"Icon matching '{icon_name}' found in theme, returning icon")
                return Gio.ThemedIcon.new(icon_name)
            else:
                logging.debug(f"Icon matching '{icon_name}' NOT found in theme")

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

        gio_file = Gio.File.new_for_path(path)

        # read metadata
        icon_name = self._read_custom_icon_name(gio_file)
        if not icon_name:
            return

        # use cache if available
        cached = self._get_cached(path)
        if cached:
            file.set_icon(cached)
            logging.debug(f"Using cached icon for {path}")
            return

        # logging.debug(f"Resolving icon for {path}...")
        themed_icon = self._resolve_themed_icon(icon_name)
        if not themed_icon:
            logging.debug("No themed icon resolved for %s on %s", icon_name, path)
            return

        # cache and return
        self._set_cache(path, themed_icon)
        file.set_icon(themed_icon)

class CustomIconNameExtension(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()
        logging.debug(f"CustomIconNameExtension initialized: {__file__})")

    def get_file_items(self, window, files):
        if len(files) != 1:
            return
        f = files[0]
        if not f.is_directory():
            return

        # Main menu item with submenu
        main_item = Nautilus.MenuItem(
            name="CustomIconNameExtension::SetIcon",
            label="Set folder icon",
            tip="Choose a custom icon for this folder"
        )
        submenu = Nautilus.Menu()
        main_item.set_submenu(submenu)

        icons = [
            "folder-biohazard",
            "folder-bong",
            "folder-burger",
            "folder-crow",
            "folder-cube",
            "folder-hat-wizard",
        ]

        for icon_name in icons:
            subitem = Nautilus.MenuItem(
                name=f"CustomIconNameExtension::SetIcon::{icon_name}",
                label=icon_name,
            )
            subitem.connect("activate", self._icon_chosen, f, icon_name)
            submenu.append_item(subitem)

        return [main_item]

    def _icon_chosen(self, menu, file, icon_name):
        folder_path = file.get_location().get_path()
        logging.debug(f"Icon '{icon_name}' chosen for folder {folder_path}")

        gio_file = Gio.File.new_for_path(folder_path)
        try:
            info = gio_file.query_info("metadata::custom-icon-name", Gio.FileQueryInfoFlags.NONE, None)
            info.set_attribute_string("metadata::custom-icon-name", icon_name)
            gio_file.set_attributes_from_info(info, Gio.FileQueryInfoFlags.NONE, None)
            logging.debug(f"Set metadata::custom-icon-name='{icon_name}' for {folder_path}")
        except Exception as e:
            logging.error(f"Failed to set custom icon metadata: {e}")

import gi
gi.require_version("Nautilus", "4.0")
from gi.repository import Nautilus, GObject, Gio
from urllib.parse import unquote

class CustomIconPropertiesModel(GObject.GObject, Nautilus.PropertiesModelProvider):
    def get_models(self, files):
        if len(files) != 1:
            return []
        file = files[0]
        if file.get_uri_scheme() != "file":
            return []

        path = unquote(file.get_uri()[7:])
        gio_file = Gio.File.new_for_path(path)

        try:
            info = gio_file.query_info("metadata::custom-icon-name", Gio.FileQueryInfoFlags.NONE, None)
            icon_name = info.get_attribute_string("metadata::custom-icon-name") or ""
        except Exception:
            icon_name = ""

        section_model = Gio.ListStore.new(item_type=Nautilus.PropertiesItem)
        section_model.append(
            Nautilus.PropertiesItem(
                name="Custom Folder Icon",
                value=icon_name,
            )
        )

        return [
            Nautilus.PropertiesModel(
                title="Custom Icon",
                model=section_model
            )
        ]
