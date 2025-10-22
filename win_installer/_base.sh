#!/usr/bin/env bash
# Copyright 2016 Christoph Reiter
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.

set -e
DIR="$( cd "$( dirname "$0" )" && pwd )"
cd "${DIR}"

# CONFIG START

ARCH="i686"
PYTHON_VERSION="2"
BUILD_VERSION="0"

# CONFIG END

MISC="${DIR}"/misc
PYTHON_ID="python${PYTHON_VERSION}"
if [ "${ARCH}" = "x86_64" ]; then
    MINGW="mingw64"
else
    MINGW="mingw32"
fi

QL_VERSION="0.0.0"
QL_VERSION_DESC="UNKNOWN"


function set_python_version {
    PYTHON_VERSION="$1"
    PYTHON_ID="python${PYTHON_VERSION}"
}

function set_build_root {
    BUILD_ROOT="$1"
    REPO_CLONE="${BUILD_ROOT}"/quodlibet
    MINGW_ROOT="${BUILD_ROOT}/${MINGW}"
}

set_build_root "${DIR}/_build_root"

function build_pacman {
    pacman --root "${BUILD_ROOT}" "$@"
}

function build_pip {
    "${BUILD_ROOT}"/"${MINGW}"/bin/"${PYTHON_ID}".exe -m pip "$@"
}

function build_python {
    "${BUILD_ROOT}"/"${MINGW}"/bin/"${PYTHON_ID}".exe "$@"
}

function build_compileall {
    if [ "${PYTHON_VERSION}" = "2" ]; then
        build_python -m compileall "$@"
    else
        build_python -m compileall -b "$@"
    fi
}

function install_pre_deps {
    pacman -S --needed --noconfirm p7zip git dos2unix \
        mingw-w64-"${ARCH}"-nsis wget intltool mingw-w64-"${ARCH}"-toolchain
}

function create_root {
    mkdir -p "${BUILD_ROOT}"

    mkdir -p "${BUILD_ROOT}"/var/lib/pacman
    mkdir -p "${BUILD_ROOT}"/var/log
    mkdir -p "${BUILD_ROOT}"/tmp

    build_pacman -Syu
    build_pacman --noconfirm -S base
}

function extract_installer {
    [ -z "$1" ] && (echo "Missing arg"; exit 1)

    mkdir -p "$BUILD_ROOT"
    7z x -o"$BUILD_ROOT"/"$MINGW" "$1"
    rm -rf "$MINGW_ROOT"/'$PLUGINSDIR' "$MINGW_ROOT"/*.txt "$MINGW_ROOT"/*.nsi
}

function install_deps {

    build_pacman --noconfirm -S git mingw-w64-"${ARCH}"-gdk-pixbuf2 \
        mingw-w64-"${ARCH}"-librsvg \
        mingw-w64-"${ARCH}"-gtk3 mingw-w64-"${ARCH}"-"${PYTHON_ID}" \
        mingw-w64-"${ARCH}"-"${PYTHON_ID}"-gobject \
        mingw-w64-"${ARCH}"-"${PYTHON_ID}"-cairo \
        mingw-w64-"${ARCH}"-"${PYTHON_ID}"-pip \
        mingw-w64-"${ARCH}"-libsoup mingw-w64-"${ARCH}"-gstreamer \
        mingw-w64-"${ARCH}"-gst-plugins-base \
        mingw-w64-"${ARCH}"-gst-plugins-good mingw-w64-"${ARCH}"-libsrtp \
        mingw-w64-"${ARCH}"-gst-plugins-bad mingw-w64-"${ARCH}"-gst-libav \
        mingw-w64-"${ARCH}"-gst-plugins-ugly

    PIP_REQUIREMENTS="\
certifi==2016.9.26
colorama==0.3.7
feedparser==5.2.1
musicbrainzngs==0.6
mutagen==1.35
pep8==1.7.0
py==1.4.31
pyflakes==1.3.0
pytest==3.0.5
"

    build_pip install --no-deps --no-binary ":all:" --upgrade \
        --force-reinstall $(echo "$PIP_REQUIREMENTS" | tr ["\\n"] [" "])

    if [ "${PYTHON_ID}" = "python2" ]; then
        build_pip install --no-deps --no-binary ":all:" --upgrade \
            --force-reinstall "futures==3.0.5"
    fi

    build_pacman --noconfirm -Rdd mingw-w64-"${ARCH}"-shared-mime-info \
        mingw-w64-"${ARCH}"-"${PYTHON_ID}"-pip mingw-w64-"${ARCH}"-ncurses \
        mingw-w64-"${ARCH}"-tk mingw-w64-"${ARCH}"-tcl \
        mingw-w64-"${ARCH}"-opencv mingw-w64-"${ARCH}"-daala-git \
        mingw-w64-"${ARCH}"-SDL2 mingw-w64-"${ARCH}"-libdvdcss \
        mingw-w64-"${ARCH}"-libdvdnav mingw-w64-"${ARCH}"-libdvdread \
        mingw-w64-"${ARCH}"-openexr mingw-w64-"${ARCH}"-openal \
        mingw-w64-"${ARCH}"-openh264 mingw-w64-"${ARCH}"-gnome-common \
        mingw-w64-"${ARCH}"-clutter  mingw-w64-"${ARCH}"-gsl \
        mingw-w64-"${ARCH}"-libvpx mingw-w64-"${ARCH}"-libcaca \
        mingw-w64-"${ARCH}"-libwebp || true

    if [ "${PYTHON_ID}" = "python2" ]; then
        build_pacman --noconfirm -Rdd mingw-w64-"${ARCH}"-python3 || true
    else
        build_pacman --noconfirm -Rdd mingw-w64-"${ARCH}"-python2 || true
    fi

    build_pacman --noconfirm -R $(build_pacman -Qdtq)
    build_pacman -S --noconfirm mingw-w64-"${ARCH}"-"${PYTHON_ID}"-setuptools

    # make loader loading relocatable
    # (hacky... but I don't understand the win/unix path translation magic)
    GDK_PIXBUF_PREFIX=$(cd "${BUILD_ROOT}" && \
        /"${MINGW}"/bin/"${PYTHON_ID}".exe \
        -c "import os; print(os.getcwd())")"/${MINGW}"
    loaders_cache="${MINGW_ROOT}"/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
    sed -i "s|$GDK_PIXBUF_PREFIX|..|g" "$loaders_cache"

    # remove the large png icons, they should be used rarely and svg works fine
    rm -Rf "${MINGW_ROOT}/share/icons/Adwaita/256x256"
    rm -Rf "${MINGW_ROOT}/share/icons/Adwaita/96x96"
    rm -Rf "${MINGW_ROOT}/share/icons/Adwaita/48x48"
    "${MINGW_ROOT}"/bin/gtk-update-icon-cache-3.0.exe \
        "${MINGW_ROOT}"/share/icons/Adwaita

    # we installed our app icons into hicolor
    "${MINGW_ROOT}"/bin/gtk-update-icon-cache-3.0.exe \
        "${MINGW_ROOT}"/share/icons/hicolor
}

function install_quodlibet {
    [ -z "$1" ] && (echo "Missing arg"; exit 1)

    rm -Rf "${REPO_CLONE}"
    git clone "${DIR}"/.. "${REPO_CLONE}"

    (cd "${REPO_CLONE}" && git checkout "$1") || exit 1

    build_python "${REPO_CLONE}"/quodlibet/setup.py install

    # Create launchers
    "${PYTHON_ID}" "${MISC}"/create-launcher.py \
        "${QL_VERSION}" "${MINGW_ROOT}"/bin

    QL_VERSION=$(MSYSTEM= build_python -c \
        "import quodlibet.const; import sys; sys.stdout.write(quodlibet.const.VERSION)")
    QL_VERSION_DESC="$QL_VERSION"
    if [ "$1" = "master" ]
    then
        local GIT_REV=$(git rev-list --count HEAD)
        local GIT_HASH=$(git rev-parse --short HEAD)
        QL_VERSION_DESC="$QL_VERSION-rev$GIT_REV-$GIT_HASH"
    fi
}

function cleanup_install {
    # delete translations we don't support
    for d in "${MINGW_ROOT}"/share/locale/*/LC_MESSAGES; do
        if [ ! -f "${d}"/quodlibet.mo ]; then
            rm -Rf "${d}"
        fi
    done

    find "${MINGW_ROOT}" -regextype "posix-extended" -name "*.exe" -a ! \
        -iregex ".*/(quodlibet|exfalso|operon|python|gspawn-)[^/]*\\.exe" \
        -exec rm -f {} \;

    rm -Rf "${MINGW_ROOT}"/libexec
    rm -Rf "${MINGW_ROOT}"/share/gtk-doc
    rm -Rf "${MINGW_ROOT}"/include
    rm -Rf "${MINGW_ROOT}"/var
    rm -Rf "${MINGW_ROOT}"/etc
    rm -Rf "${MINGW_ROOT}"/share/zsh
    rm -Rf "${MINGW_ROOT}"/share/pixmaps
    rm -Rf "${MINGW_ROOT}"/share/gnome-shell
    rm -Rf "${MINGW_ROOT}"/share/dbus-1
    rm -Rf "${MINGW_ROOT}"/share/gir-1.0
    rm -Rf "${MINGW_ROOT}"/share/doc
    rm -Rf "${MINGW_ROOT}"/share/man
    rm -Rf "${MINGW_ROOT}"/share/info
    rm -Rf "${MINGW_ROOT}"/share/mime
    rm -Rf "${MINGW_ROOT}"/share/gettext
    rm -Rf "${MINGW_ROOT}"/share/libtool
    rm -Rf "${MINGW_ROOT}"/share/licenses
    rm -Rf "${MINGW_ROOT}"/share/appdata
    rm -Rf "${MINGW_ROOT}"/share/aclocal
    rm -Rf "${MINGW_ROOT}"/share/ffmpeg
    rm -Rf "${MINGW_ROOT}"/share/vala
    rm -Rf "${MINGW_ROOT}"/share/readline
    rm -Rf "${MINGW_ROOT}"/share/icons/Adwaita/cursors
    rm -Rf "${MINGW_ROOT}"/share/xml
    rm -Rf "${MINGW_ROOT}"/share/bash-completion
    rm -Rf "${MINGW_ROOT}"/share/common-lisp
    rm -Rf "${MINGW_ROOT}"/share/emacs
    rm -Rf "${MINGW_ROOT}"/share/gdb
    rm -Rf "${MINGW_ROOT}"/share/libcaca
    rm -Rf "${MINGW_ROOT}"/share/gettext
    rm -Rf "${MINGW_ROOT}"/share/gst-plugins-base
    rm -Rf "${MINGW_ROOT}"/share/gtk-3.0
    rm -Rf "${MINGW_ROOT}"/share/nghttp2
    rm -Rf "${MINGW_ROOT}"/share/themes
    rm -Rf "${MINGW_ROOT}"/share/fontconfig
    rm -Rf "${MINGW_ROOT}"/share/gettext-*
    rm -Rf "${MINGW_ROOT}"/share/gstreamer-1.0

    find "${MINGW_ROOT}"/share/glib-2.0 -type f ! \
        -name "*.compiled" -exec rm -f {} \;

    rm -Rf "${MINGW_ROOT}"/lib/"${PYTHON_ID}".*/test
    rm -Rf "${MINGW_ROOT}"/lib/cmake
    rm -Rf "${MINGW_ROOT}"/lib/gettext
    rm -Rf "${MINGW_ROOT}"/lib/gtk-3.0
    rm -Rf "${MINGW_ROOT}"/lib/mpg123
    rm -Rf "${MINGW_ROOT}"/lib/p11-kit
    rm -Rf "${MINGW_ROOT}"/lib/ruby

    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstvpx.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstdaala.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstdvdread.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstopenal.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstopenexr.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstopenh264.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstresindvd.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstassrender.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstx265.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstwebp.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstopengl.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstmxf.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstfaac.dll
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstschro.dll

    rm -f "${MINGW_ROOT}"/bin/libharfbuzz-icu-0.dll
    rm -f "${MINGW_ROOT}"/lib/"${PYTHON_ID}".*/lib-dynload/_tkinter*
    rm -f "${MINGW_ROOT}"/lib/gstreamer-1.0/libgstcacasink.dll

    if [ "${PYTHON_VERSION}" = "2" ]; then
        rm -Rf "${MINGW_ROOT}"/lib/python3.*
    else
        rm -Rf "${MINGW_ROOT}"/lib/python2.*
    fi

    find "${MINGW_ROOT}" -name "*.a" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.whl" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.h" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.la" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.sh" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.jar" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.def" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.cmd" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.cmake" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.pc" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.desktop" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.manifest" -exec rm -f {} \;
    find "${MINGW_ROOT}" -name "*.pyo" -exec rm -f {} \;

    find "${MINGW_ROOT}"/bin -name "*-config" -exec rm -f {} \;
    find "${MINGW_ROOT}"/bin -name "easy_install*" -exec rm -f {} \;
    find "${MINGW_ROOT}" -regex ".*/bin/[^.]+" -exec rm -f {} \;
    find "${MINGW_ROOT}" -regex ".*/bin/[^.]+\\.[0-9]+" -exec rm -f {} \;

    find "${MINGW_ROOT}" -name "gtk30-properties.mo" -exec rm -rf {} \;
    find "${MINGW_ROOT}" -name "gettext-tools.mo" -exec rm -rf {} \;

    find "${MINGW_ROOT}" -name "old_root.pem" -exec rm -rf {} \;
    find "${MINGW_ROOT}" -name "weak.pem" -exec rm -rf {} \;

    find "${MINGW_ROOT}"/lib/"${PYTHON_ID}".* -type d -name "test*" \
        -prune -exec rm -rf {} \;

    find "${MINGW_ROOT}"/lib/"${PYTHON_ID}".* -type d -name "*_test*" \
        -prune -exec rm -rf {} \;

    find "${MINGW_ROOT}"/bin -name "*.pyo" -exec rm -f {} \;
    find "${MINGW_ROOT}"/bin -name "*.pyc" -exec rm -f {} \;
    build_compileall -q "${MINGW_ROOT}"
    find "${MINGW_ROOT}" -name "*.py" -exec rm -f {} \;
    find "${MINGW_ROOT}"/bin -name "*.pyc" -exec rm -f {} \;
    find "${MINGW_ROOT}" -type d -name "__pycache__" -prune -exec rm -rf {} \;

    build_python "${MISC}/depcheck.py"

    find "${MINGW_ROOT}" -type d -empty -delete
}

function build_installer {
    BUILDPY=$(echo "${MINGW_ROOT}"/lib/"${PYTHON_ID}".*/site-packages/quodlibet)/build.py
    cp "${REPO_CLONE}"/quodlibet/quodlibet/build.py "$BUILDPY"
    echo 'BUILD_TYPE = u"windows"' >> "$BUILDPY"
    echo "BUILD_VERSION = $BUILD_VERSION" >> "$BUILDPY"
    (cd "$REPO_CLONE" && echo "BUILD_INFO = u\"$(git rev-parse --short HEAD)\"" >> "$BUILDPY")
    (cd $(dirname "$BUILDPY") && build_compileall -q -f -l .)
    rm -f "$BUILDPY"

    cp misc/quodlibet.ico "${BUILD_ROOT}"
    (cd "$BUILD_ROOT" && makensis -NOCD -DVERSION="$QL_VERSION_DESC" "${MISC}"/win_installer.nsi)

    mv "$BUILD_ROOT/quodlibet-LATEST.exe" "$DIR/quodlibet-$QL_VERSION_DESC-installer.exe"
}

function build_portable_installer {
    BUILDPY=$(echo "${MINGW_ROOT}"/lib/"${PYTHON_ID}".*/site-packages/quodlibet)/build.py
    cp "${REPO_CLONE}"/quodlibet/quodlibet/build.py "$BUILDPY"
    echo 'BUILD_TYPE = u"windows-portable"' >> "$BUILDPY"
    echo "BUILD_VERSION = $BUILD_VERSION" >> "$BUILDPY"
    (cd "$REPO_CLONE" && echo "BUILD_INFO = u\"$(git rev-parse --short HEAD)\"" >> "$BUILDPY")
    (cd $(dirname "$BUILDPY") && build_compileall -q -f -l .)
    rm -f "$BUILDPY"

    local PORTABLE="$DIR/quodlibet-$QL_VERSION_DESC-portable"

    rm -rf "$PORTABLE"
    mkdir "$PORTABLE"
    cp "$MISC"/quodlibet.lnk "$PORTABLE"
    cp "$MISC"/exfalso.lnk "$PORTABLE"
    cp "$MISC"/README-PORTABLE.txt "$PORTABLE"/README.txt
    unix2dos "$PORTABLE"/README.txt
    mkdir "$PORTABLE"/config
    cp -RT "${MINGW_ROOT}" "$PORTABLE"/data

    rm -Rf 7zout 7z1604.exe
    7z a payload.7z "$PORTABLE"
    wget -P "$DIR" -c http://www.7-zip.org/a/7z1604.exe
    7z x -o7zout 7z1604.exe
    cat 7zout/7z.sfx payload.7z > "$PORTABLE".exe
    rm -Rf 7zout 7z1604.exe payload.7z "$PORTABLE"
}
