#!/usr/bin/env bash
set -euo pipefail
alias wget='wget --https-only --secure-protocol=TLSv1_2'

###############################################
# Config
###############################################

VERSION="4.1.0"
APPDIR="$(pwd)/AppDir"
PATCH_URL="https://patch-diff.githubusercontent.com/raw/tom-james-watson/Emote/pull/154.patch"
PYVER="3.6"

###############################################
# Fetch appimagetool dynamically
###############################################

APPIMAGETOOL="$HOME/Programs/appimagetool-x86_64.AppImage"

mkdir -p "$HOME/Programs"

if [ ! -f "$APPIMAGETOOL" ]; then
    echo "Downloading appimagetool..."
    wget -O "$APPIMAGETOOL" \
      "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x "$APPIMAGETOOL"
fi

###############################################
# Install Python packages (user-level)
###############################################

python${PYVER} -m pip install --user --upgrade pip setproctitle

###############################################
# Prepare sources
###############################################

rm -rf "$APPDIR" Emote-* "v${VERSION}.tar.gz" 154.patch wayland-paste.patch

wget -O "v${VERSION}.tar.gz" \
  "https://github.com/tom-james-watson/Emote/archive/refs/tags/v${VERSION}.tar.gz"

tar xf "v${VERSION}.tar.gz"
cd "Emote-${VERSION}"

wget -O 154.patch "$PATCH_URL"
patch -p1 < 154.patch

###############################################
# Apply Wayland paste patch
###############################################

cat > wayland-paste.patch << 'EOF'
--- a/emote/picker.py
+++ b/emote/picker.py
@@ -646,11 +646,19 @@
             self.add_emoji_to_recent(emoji)
             self.copy_to_clipboard(emoji)

+        # Let GTK process clipboard events
+        for _ in range(10):
+            while Gtk.events_pending():
+                Gtk.main_iteration_do(False)
+            time.sleep(0.005)
+
         self.destroy()

-        if not config.is_wayland:
-            time.sleep(0.15)
-            os.system("xdotool key ctrl+v")
+        if config.is_wayland:
+            os.system('bash -c "sleep 0.15; ydotool key 29:1 47:1 47:0 29:0" &')
+        else:
+             time.sleep(0.15)
+             os.system("xdotool key ctrl+v")

     def add_emoji_to_recent(self, emoji):
         user_data.update_recent_emojis(emoji)
EOF

patch -p1 < wayland-paste.patch

###############################################
# Install into AppDir
###############################################

SITE_PACKAGES="$APPDIR/usr/lib/python${PYVER}/site-packages"

mkdir -p "$SITE_PACKAGES/emote"
cp -r emote/* "$SITE_PACKAGES/emote/"

cd ..

###############################################
# Bundle Python (CentOS/OL8 layout)
###############################################

mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/lib/python${PYVER}"

# Interpreter
if [ -x "/usr/bin/python${PYVER}" ]; then
    cp "/usr/bin/python${PYVER}" "$APPDIR/usr/bin/python${PYVER}"
else
    echo "ERROR: python${PYVER} interpreter not found"
    exit 1
fi

# libpython (required)
if ls /usr/lib64/libpython${PYVER}*.so* 1>/dev/null 2>&1; then
    cp /usr/lib64/libpython${PYVER}*.so* "$APPDIR/usr/lib/"
else
    echo "ERROR: libpython${PYVER} not found"
    exit 1
fi

# Standard library
if [ -d "/usr/lib64/python${PYVER}" ]; then
    cp -r /usr/lib64/python${PYVER}/* "$APPDIR/usr/lib/python${PYVER}/"
else
    echo "ERROR: Python ${PYVER} standard library missing"
    exit 1
fi

###############################################
# Copy setproctitle (installed via --user)
###############################################

SITE="$HOME/.local/lib/python${PYVER}/site-packages"

if ls "$SITE"/setproctitle*.so 1>/dev/null 2>&1; then
    cp "$SITE"/setproctitle*.so "$SITE_PACKAGES"/
else
    echo "ERROR: setproctitle not found in user site-packages"
    exit 1
fi

###############################################
# Static assets (CSS, icons, emojis)
###############################################

STATIC_DIR="$SITE_PACKAGES/emote/static"
mkdir -p "$STATIC_DIR"

cp "Emote-${VERSION}/static/style.css" "$STATIC_DIR/"
cp "Emote-${VERSION}/static/logo.svg" "$STATIC_DIR/"

wget -O "$STATIC_DIR/emojis.csv" \
  "https://raw.githubusercontent.com/hfg-gmuend/openmoji/refs/tags/16.0.0/data/openmoji.csv"

cp "Emote-${VERSION}/static/com.tomjwatson.Emote.desktop" "$APPDIR/emote.desktop"
sed -i 's/Icon=.*/Icon=emote/' "$APPDIR/emote.desktop"
sed -i 's/Exec=.*/Exec=emote/' "$APPDIR/emote.desktop"

cp "Emote-${VERSION}/static/logo.svg" "$APPDIR/emote.svg"

mkdir -p "$APPDIR/usr/share/applications"
cp "$APPDIR/emote.desktop" "$APPDIR/usr/share/applications/emote.desktop"

mkdir -p "$APPDIR/usr/share/icons/hicolor/scalable/apps"
cp "$APPDIR/emote.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/emote.svg"

###############################################
# Bundle Keybinder
###############################################

LIBKEYBINDER="/usr/lib64/libkeybinder-3.0.so"

if ls "$LIBKEYBINDER"* 1>/dev/null 2>&1; then
    cp "$LIBKEYBINDER"* "$APPDIR/usr/lib/"
else
    echo "ERROR: libkeybinder missing"
    exit 1
fi

###############################################
# Bundle GI typelibs
###############################################

mkdir -p "$APPDIR/usr/lib/girepository-1.0"

KEYBINDER_TLIB="/usr/lib64/girepository-1.0/Keybinder-3.0.typelib"

if [ -f "$KEYBINDER_TLIB" ]; then
    cp "$KEYBINDER_TLIB" "$APPDIR/usr/lib/girepository-1.0/"
else
    echo "ERROR: Keybinder typelib missing – Emote won't run"
    exit 1
fi

###############################################
# Bundle PyGObject and PyCairo
###############################################

SYSTEM_PACKAGES="/usr/lib64/python${PYVER}/site-packages"

if [ -d "$SYSTEM_PACKAGES/gi" ]; then
    cp -r "$SYSTEM_PACKAGES/gi" \
        "$SITE_PACKAGES/"
else
    echo "ERROR: PyGObject (gi) missing – required for typelibs"
    exit 1
fi

if ls $SYSTEM_PACKAGES/pycairo* 1>/dev/null 2>&1; then
    cp -r $SYSTEM_PACKAGES/pycairo* \
        "$SITE_PACKAGES/"
else
    echo "ERROR: PyCairo missing – required for GTK"
    exit 1
fi

###############################################
# Bundle minimal extra libs
###############################################

for lib in \
  /usr/lib64/libcrypto.so.1.1* \
  /usr/lib64/libssl.so.1.1* \
  /usr/lib64/libffi.so.6*
do
    if ls $lib 1>/dev/null 2>&1; then
        cp $lib "$APPDIR/usr/lib/"
    else
        echo "ERROR: Required library missing: $lib"
        exit 1
    fi
done

# Ensure libffi.so.6 symlink exists (for Python 3.6)
if ls "$APPDIR/usr/lib/libffi.so.6."* >/dev/null 2>&1; then
    realffi="$(basename "$(ls "$APPDIR/usr/lib/libffi.so.6."* | head -n1)")"
    ln -sf "$realffi" "$APPDIR/usr/lib/libffi.so.6"
fi

###############################################
# AppRun
###############################################

cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
set -euo pipefail

HERE="$(dirname "$(readlink -f "$0")")"

PYDIR="$(ls "$HERE/usr/lib" | grep -E '^python[0-9]+\.[0-9]+$' | head -n1)"
PYVER="${PYDIR#python}"

# Use only bundled GI typelibs first
export GI_TYPELIB_PATH="$HERE/usr/lib/girepository-1.0"

# Python environment
export PYTHONHOME="$HERE/usr"
export PYTHONPATH="$HERE/usr/lib/python${PYVER}:$HERE/usr/lib/python${PYVER}/site-packages:$HERE/usr/lib/python${PYVER}/lib-dynload"
export PYTHONPLATLIBDIR="lib-dynload"

# Use only bundled libs first
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"

# Change directory for relative paths to work
cd "$HERE/usr/lib/python${PYVER}/site-packages/emote"

echo "Running Emote from: $(pwd)"

exec "$HERE/usr/bin/python${PYVER}" __main__.py "$@"
EOF

chmod +x "$APPDIR/AppRun"

###############################################
# Build AppImage
###############################################

ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR"

###############################################
# Cleanup
###############################################

shopt -s extglob
rm -rf "$APPDIR" Emote-!(*.AppImage) "v${VERSION}.tar.gz" 154.patch wayland-paste.patch

echo "Done"
