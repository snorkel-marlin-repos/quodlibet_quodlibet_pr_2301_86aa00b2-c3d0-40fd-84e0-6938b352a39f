# -*- coding: utf-8 -*-
# Copyright 2004-2005 Joe Wreschnig, Michael Urman, Iñigo Serna
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation

from gi.repository import Gtk

from quodlibet import _
from quodlibet.qltk import get_top_parent
from quodlibet.qltk import Icons
from quodlibet.qltk.window import Dialog


class FolderChooser(Gtk.FileChooserDialog, Dialog):
    """Choose folders and return them when run.

    Note: works with glib paths
    """

    def __init__(self, parent, title, initial_dir=None,
                 action=Gtk.FileChooserAction.SELECT_FOLDER):
        super(FolderChooser, self).__init__(
            title=title, transient_for=get_top_parent(parent), action=action)

        self.add_button(_("_Cancel"), Gtk.ResponseType.CANCEL)
        self.add_icon_button(_("_Open"), Icons.DOCUMENT_OPEN,
                             Gtk.ResponseType.OK)

        if initial_dir:
            self.set_current_folder(initial_dir)
        self.set_local_only(True)
        self.set_select_multiple(True)

    def run(self):
        resp = super(FolderChooser, self).run()
        fns = self.get_filenames()
        if resp == Gtk.ResponseType.OK:
            return fns
        else:
            return []


class FileChooser(FolderChooser):
    """Choose files and return them when run."""

    def __init__(self, parent, title, filter=None, initial_dir=None):
        super(FileChooser, self).__init__(
            parent, title, initial_dir, Gtk.FileChooserAction.OPEN)
        if filter:
            def new_filter(args, realfilter):
                return realfilter(args.filename)
            f = Gtk.FileFilter()
            f.set_name(_("Songs"))
            f.add_custom(Gtk.FileFilterFlags.FILENAME, new_filter, filter)
            self.add_filter(f)
