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
# Apply quality of life patch
###############################################

cat > qol.patch << 'EOF'
--- a/emote/picker.py
+++ b/emote/picker.py
@@ -1,5 +1,6 @@
 import os
 import time
+import regex
 from datetime import datetime
 import gi
 from itertools import zip_longest
@@ -206,51 +207,68 @@
 
         self.previewed_emoji_label = Gtk.Label(" ")
         self.previewed_emoji_label.set_name("previewed_emoji_label")
-        self.previewed_emoji_label.set_alignment(0, 0.2)
+        self.previewed_emoji_label.set_alignment(0, 0.5)
         self.emoji_preview_box.pack_start(self.previewed_emoji_label, False, False, 0)
 
         self.emoji_preview_box_text = Gtk.Box(
             spacing=0, orientation=Gtk.Orientation.VERTICAL
         )
+
+        self.emoji_preview_box_text.set_size_request(200, -1)
+
         self.previewed_emoji_name_label = Gtk.Label(
-            " ", ellipsize=Pango.EllipsizeMode.END
+            " ", ellipsize=Pango.EllipsizeMode.END, max_width_chars=22
         )
         self.previewed_emoji_name_label.set_name("previewed_emoji_name_label")
-        self.previewed_emoji_name_label.set_alignment(0, 0.2)
+        self.previewed_emoji_name_label.set_alignment(0, 0.5)
+
         self.emoji_preview_box_text.pack_start(
-            self.previewed_emoji_name_label, False, False, 0
+            self.previewed_emoji_name_label, True, True, 0
         )
 
         self.previewed_emoji_shortcode_label = Gtk.Label(
-            " ", ellipsize=Pango.EllipsizeMode.END
+            " ", ellipsize=Pango.EllipsizeMode.END, max_width_chars=22
         )
         self.previewed_emoji_shortcode_label.set_name("previewed_emoji_shortcode_label")
-        self.previewed_emoji_shortcode_label.set_alignment(0, 0.2)
+        self.previewed_emoji_shortcode_label.set_alignment(0, 0.5)
+
         self.emoji_preview_box_text.pack_start(
-            self.previewed_emoji_shortcode_label, False, False, 0
+            self.previewed_emoji_shortcode_label, True, True, 0
         )
 
-        self.emoji_preview_box.pack_start(self.emoji_preview_box_text, False, False, 0)
+        self.emoji_preview_box.pack_start(self.emoji_preview_box_text, False, False, 6)
 
         self.action_bar.pack_start(self.emoji_preview_box)
 
-        self.selected_box = Gtk.Box(
-            spacing=GRID_SIZE, margin=GRID_SIZE, margin_bottom=0, expand=False
-        )
+        self.selected_eventbox = Gtk.EventBox()
+        self.selected_eventbox.set_visible_window(False)
+        self.selected_eventbox.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
 
         self.emoji_append_list_preview = Gtk.Label(
-            " ", max_width_chars=25, ellipsize=Pango.EllipsizeMode.START
+            " ", ellipsize=Pango.EllipsizeMode.START
         )
         self.emoji_append_list_preview.set_name("emoji_append_list_preview")
-        self.selected_box.pack_start(self.emoji_append_list_preview, False, False, 0)
+        self.selected_eventbox.add(self.emoji_append_list_preview)
 
-        self.action_bar.pack_end(self.selected_box)
+        self.selected_eventbox.connect(
+            "button-press-event", self.on_selected_box_middle_click
+        )
 
+        self.action_bar.pack_end(self.selected_eventbox)
         self.action_bar.show_all()
-        self.selected_box.hide()
 
         self.app_container.pack_end(self.action_bar, False, False, 0)
 
+    def on_selected_box_middle_click(self, widget, event):
+        """Clear emoji list on middle click (button 2)"""
+        if event.button == 2:  # Middle mouse button
+            print("✅ Cleared emoji selection!")
+            self.emoji_append_list = []
+            self.copy_to_clipboard("")
+            self.update_emoji_append_list_preview()
+            return True
+        return False
+
     def get_skintone_char(self, emoji):
         char = emoji["char"]
 
@@ -282,9 +300,29 @@
             self.previewed_emoji_name_label.set_text(" ")
             self.previewed_emoji_shortcode_label.set_text(" ")
 
+    def split_graphemes(self, text):
+        return regex.findall(r"\X", text)
+
+    def wrap_emoji_lines(self, graphemes, per_line=10):
+        lines = []
+        for i in range(0, len(graphemes), per_line):
+            lines.append("".join(graphemes[i:i+per_line]))
+        return "\n".join(lines)
+
     def update_emoji_append_list_preview(self):
-        self.emoji_append_list_preview.show_all()
-        self.emoji_append_list_preview.set_text("".join(self.emoji_append_list))
+        text = "".join(self.emoji_append_list)
+
+        graphemes = self.split_graphemes(text)
+        wrapped = self.wrap_emoji_lines(graphemes, per_line=10)
+
+        self.emoji_append_list_preview.set_text(wrapped)
+        self.emoji_append_list_preview.set_line_wrap(True)
+        self.emoji_append_list_preview.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
+
+        if graphemes:
+            self.selected_eventbox.show()
+        else:
+            self.selected_eventbox.hide()
 
     def check_welcome(self, show_welcome):
         """Show the guide the first time we run the app"""
@@ -619,11 +657,6 @@
         print(f"Appending {emoji} to selection")
         self.emoji_append_list.append(emoji)
 
-        if len(self.emoji_append_list) == 1:
-            self.selected_box.show_all()
-            self.previewed_emoji_name_label.set_max_width_chars(20)
-            self.previewed_emoji_shortcode_label.set_max_width_chars(20)
-
         self.update_emoji_append_list_preview()
 
         self.copy_to_clipboard("".join(self.emoji_append_list))
@@ -646,11 +679,19 @@
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
+            time.sleep(0.15)
+            os.system("xdotool key ctrl+v")
 
     def add_emoji_to_recent(self, emoji):
         user_data.update_recent_emojis(emoji)

EOF

patch -p1 < qol.patch

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

SITE_USER="$HOME/.local/lib/python${PYVER}/site-packages"

if ls "$SITE_USER"/setproctitle*.so 1>/dev/null 2>&1; then
    cp "$SITE_USER"/setproctitle*.so "$SITE_PACKAGES"/
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
sed -i '/^Keywords=/ s/,/;/g' "$APPDIR/emote.desktop"

cp "Emote-${VERSION}/static/logo.svg" "$APPDIR/emote.svg"

mkdir -p "$APPDIR/usr/share/applications"
cp "$APPDIR/emote.desktop" "$APPDIR/usr/share/applications/emote.desktop"

mkdir -p "$APPDIR/usr/share/icons/hicolor/scalable/apps"
cp "$APPDIR/emote.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/emote.svg"

###############################################
# Bundle xdotool
###############################################

XDOTOOL="/usr/bin/xdotool"

if ls "$XDOTOOL" 1>/dev/null 2>&1; then
    cp "$XDOTOOL" "$APPDIR/usr/bin/"
else
    echo "ERROR: xdotool missing"
    exit 1
fi

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
# Bundle Keybinder typelib
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

if ls $SYSTEM_PACKAGES/regex* 1>/dev/null 2>&1; then
    cp -r $SYSTEM_PACKAGES/regex* \
        "$SITE_PACKAGES/"
else
    echo "ERROR: regex missing – required for splitting emoji sequences"
    exit 1
fi

###############################################
# Bundle minimal extra libs
###############################################

for lib in \
  /usr/lib64/libcrypto.so.1.1* \
  /usr/lib64/libssl.so.1.1* \
  /usr/lib64/libffi.so.6* \
  /usr/lib64/libxdo.so.3*
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
# Registration script
###############################################

cat > "$APPDIR/usr/bin/registration" << 'EOF'
#!/bin/bash
set -euo pipefail

ACTION="${1:-}"
APPDIR="${2:-}"

ICON_SRC="$APPDIR/emote.svg"
DESKTOP_SRC="$APPDIR/emote.desktop"

ICON_TARGET1="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_TARGET2="$HOME/.icons/hicolor/scalable/apps"
DESKTOP_TARGET="$HOME/.local/share/applications"

register() {
    echo "Where to place the Emote icon?"
    echo "(1) ~/.local/share/icons"
    echo "(2) ~/.icons"
    echo "Any other key to cancel"
    read -r choice

    case "$choice" in
        1) ICON_DEST="$ICON_TARGET1" ;;
        2) ICON_DEST="$ICON_TARGET2" ;;
        *) echo "Canceled"; exit 0 ;;
    esac

    mkdir -p "$ICON_DEST"
    cp "$ICON_SRC" "$ICON_DEST/emote.svg"

    mkdir -p "$DESKTOP_TARGET"
    cp "$DESKTOP_SRC" "$DESKTOP_TARGET/emote.desktop"

    # Fix Exec to point to the AppImage
    sed -i "s|^Exec=.*|Exec=$APPIMAGE|" "$DESKTOP_TARGET/emote.desktop"

    echo "Emote registered"
}

unregister() {
    rm -f "$ICON_TARGET1/emote.svg"
    rm -f "$ICON_TARGET2/emote.svg"
    rm -f "$DESKTOP_TARGET/emote.desktop"

    echo "Emote unregistered"
}

case "$ACTION" in
    --register) register ;;
    --unregister) unregister ;;
    *) echo "Unknown action"; exit 1 ;;
esac
EOF

chmod +x "$APPDIR/usr/bin/registration"

###############################################
# AppRun
###############################################

cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
set -euo pipefail

HERE="$(dirname "$(readlink -f "$0")")"

if [[ "${1:-}" == "--reg" || "${1:-}" == "-r" ]]; then
    exec "$HERE/usr/bin/registration" --register "$HERE"
fi

if [[ "${1:-}" == "--unreg" || "${1:-}" == "-u" ]]; then
    exec "$HERE/usr/bin/registration" --unregister "$HERE"
fi

PYDIR="$(ls "$HERE/usr/lib" | grep -E '^python[0-9]+\.[0-9]+$' | head -n1)"
PYVER="${PYDIR#python}"

# Use only bundled binaries first
export PATH="$HERE/usr/bin:$PATH"

# Use only bundled GI typelibs first
export GI_TYPELIB_PATH="$HERE/usr/lib/girepository-1.0"

# Use only bundled libs first
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"

# Python environment
export PYTHONHOME="$HERE/usr"
export PYTHONPATH="$HERE/usr/lib/python${PYVER}:$HERE/usr/lib/python${PYVER}/site-packages:$HERE/usr/lib/python${PYVER}/lib-dynload"
export PYTHONPLATLIBDIR="lib-dynload"

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
