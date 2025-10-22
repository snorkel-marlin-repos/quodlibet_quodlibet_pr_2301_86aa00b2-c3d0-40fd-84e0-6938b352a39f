#!/usr/bin/env bash
# Copyright 2016 Christoph Reiter
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.

set -e

function install_python_packages {
    pacman --noconfirm -S --needed \
        mingw-w64-i686-python$1 \
        mingw-w64-i686-python$1-gobject \
        mingw-w64-i686-python$1-cairo \
        mingw-w64-i686-python$1-pip

    pip$1 install certifi feedparser musicbrainzngs mutagen pep8 \
        pyflakes pytest

    if [ "$1" = "2" ]; then
        pip$1 install futures
    fi

}

function main {
    pacman --noconfirm -Suy

    pacman --noconfirm -S --needed \
        git mingw-w64-i686-gdk-pixbuf2 \
        mingw-w64-i686-librsvg \
        mingw-w64-i686-gtk3 \
        mingw-w64-i686-libsoup mingw-w64-i686-gstreamer \
        mingw-w64-i686-gst-plugins-base \
        mingw-w64-i686-gst-plugins-good mingw-w64-i686-libsrtp \
        mingw-w64-i686-gst-plugins-bad mingw-w64-i686-gst-libav \
        mingw-w64-i686-gst-plugins-ugly intltool

    install_python_packages 2
    install_python_packages 3
}

main;
