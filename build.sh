#!/usr/bin/env bash
set -euo pipefail
alias wget='wget --https-only --secure-protocol=TLSv1_2'

###############################################
# Config
###############################################

VERSION="4.1.0"
APPDIR="AppDir"
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

python3.6 -m pip install --user --upgrade pip setuptools wheel
python3.6 -m pip install --user setproctitle

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

mkdir -p "../${APPDIR}"

python3 setup.py install \
  --root "../${APPDIR}" \
  --prefix=/usr \
  --optimize=1

cd ..

###############################################
# Bundle Python 3.6 (CentOS/OL8 layout)
###############################################

mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/lib/python${PYVER}"

# Interpreter (explicit 3.6)
cp /usr/bin/python3.6 "$APPDIR/usr/bin/python${PYVER}"

# libpython (if present)
cp /usr/lib64/libpython${PYVER}*.so* "$APPDIR/usr/lib/" 2>/dev/null || true

# Standard library
cp -r /usr/lib64/python${PYVER}/* "$APPDIR/usr/lib/python${PYVER}/" 2>/dev/null || true

###############################################
# Copy setproctitle (user or system installed)
###############################################

mkdir -p "$APPDIR/usr/lib/python${PYVER}/site-packages"

USERPT="$HOME/.local/lib/python${PYVER}/site-packages/setproctitle"*.so
USERPT64="$HOME/.local/lib64/python${PYVER}/site-packages/setproctitle"*.so
SYS1="/usr/lib64/python${PYVER}/site-packages/setproctitle"*.so
SYS2="/usr/local/lib64/python${PYVER}/site-packages/setproctitle"*.so

if ls $USERPT 1>/dev/null 2>&1; then
    cp $USERPT "$APPDIR/usr/lib/python${PYVER}/site-packages/"
elif ls $USERPT64 1>/dev/null 2>&1; then
    cp $USERPT64 "$APPDIR/usr/lib/python${PYVER}/site-packages/"
elif ls $SYS1 1>/dev/null 2>&1; then
    cp $SYS1 "$APPDIR/usr/lib/python${PYVER}/site-packages/"
elif ls $SYS2 1>/dev/null 2>&1; then
    cp $SYS2 "$APPDIR/usr/lib/python${PYVER}/site-packages/"
else
    echo "ERROR: setproctitle not installed for Python ${PYVER}"
    exit 1
fi

###############################################
# Static assets (CSS, icons, emojis)
###############################################

STATIC_DIR="$APPDIR/usr/lib/python${PYVER}/site-packages/emote/static"
mkdir -p "$STATIC_DIR"

cp "Emote-${VERSION}/static/style.css" "$STATIC_DIR/"
cp "Emote-${VERSION}/static/logo.svg" "$STATIC_DIR/"

wget -O "$STATIC_DIR/emojis.csv" \
  "https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/data/openmoji.csv"

cp "Emote-${VERSION}/static/com.tomjwatson.Emote.desktop" "$APPDIR/emote.desktop"
sed -i 's/Icon=.*/Icon=emote/' "$APPDIR/emote.desktop"
sed -i 's/Exec=.*/Exec=emote/' "$APPDIR/emote.desktop"

cp "Emote-${VERSION}/static/logo.svg" "$APPDIR/emote.svg"

mkdir -p "$APPDIR/usr/share/applications"
cp "$APPDIR/emote.desktop" "$APPDIR/usr/share/applications/emote.desktop"

mkdir -p "$APPDIR/usr/share/icons/hicolor/scalable/apps"
cp "$APPDIR/emote.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/emote.svg"

###############################################
# Bundle Keybinder (safe-to-bundle components)
###############################################

mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/lib/girepository-1.0"
mkdir -p "$APPDIR/usr/share/gir-1.0"

# Keybinder shared library (safe)
cp /usr/lib64/libkeybinder-3.0.so* \
   "$APPDIR/usr/lib/" 2>/dev/null || true

# GI typelib (safe)
cp /usr/lib64/girepository-1.0/Keybinder-3.0.typelib \
   "$APPDIR/usr/lib/girepository-1.0/" 2>/dev/null || true

# GIR XML (optional, not required at runtime)
cp /usr/share/gir-1.0/Keybinder-3.0.gir \
   "$APPDIR/usr/share/gir-1.0/" 2>/dev/null || true

###############################################
# Bundle GI typelibs (CentOS/OL8 versions)
###############################################

mkdir -p "$APPDIR/usr/lib/girepository-1.0"
cp /usr/lib64/girepository-1.0/*.typelib \
   "$APPDIR/usr/lib/girepository-1.0/" 2>/dev/null || true

###############################################
# Bundle PyGObject and PyCairo (CentOS/OL8)
###############################################

mkdir -p "$APPDIR/usr/lib/python${PYVER}/site-packages"

cp -r /usr/lib64/python${PYVER}/site-packages/gi \
      "$APPDIR/usr/lib/python${PYVER}/site-packages/" 2>/dev/null || true

cp -r /usr/lib64/python${PYVER}/site-packages/pycairo* \
      "$APPDIR/usr/lib/python${PYVER}/site-packages/" 2>/dev/null || true

###############################################
# Bundle only minimal extra libs (safe)
###############################################

bundle_libs=(
  /usr/lib64/libcrypto.so.1.1*
  /usr/lib64/libssl.so.1.1*
  /usr/lib64/libffi.so.6*
)

for lib in "${bundle_libs[@]}"; do
  cp $lib "$APPDIR/usr/lib/" 2>/dev/null || true
done

# Ensure libffi.so.6 symlink exists (for Python 3.6)
if ls "$APPDIR/usr/lib/libffi.so.6."* >/dev/null 2>&1; then
    realffi="$(basename "$(ls "$APPDIR/usr/lib/libffi.so.6."* | head -n1)")"
    ln -sf "$realffi" "$APPDIR/usr/lib/libffi.so.6"
fi

###############################################
# AppRun (self-contained runtime)
###############################################

cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
set -euo pipefail

HERE="$(dirname "$(readlink -f "$0")")"

PYDIR="$(ls "$HERE/usr/lib" | grep -E '^python[0-9]+\.[0-9]+$' | head -n1)"
PYVER="${PYDIR#python}"

# Use only bundled GI typelibs
export GI_TYPELIB_PATH="$HERE/usr/lib/girepository-1.0"

# Python environment
export PYTHONHOME="$HERE/usr"
export PYTHONPATH="$HERE/usr/lib/python${PYVER}:$HERE/usr/lib/python${PYVER}/site-packages:$HERE/usr/lib/python${PYVER}/lib-dynload"
export PYTHONPLATLIBDIR="lib-dynload"

# Use only bundled libs first
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"

cd "$HERE/usr/lib/python${PYVER}/site-packages/emote" 2>/dev/null \
 || cd "$HERE/usr/lib64/python${PYVER}/site-packages/emote" 2>/dev/null \
 || { echo "Cannot locate Emote package directory"; exit 1; }

echo "Running Emote from: $(pwd)"

exec "$HERE/usr/bin/python${PYVER}" -m emote "$@"
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
