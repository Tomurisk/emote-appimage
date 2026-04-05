#!/usr/bin/env bash
set -euo pipefail
alias wget='wget --https-only --secure-protocol=TLSv1_2'

###############################################
# Config
###############################################

# Content blocks
source content_blocks.sh

# Versions
VERSION="4.1.0"
AIT_VER="1.9.1"
PYVER="3.6"

# Definitions
AIT_DIR="/tmp/appimagetool"
APPDIR="$(pwd)/AppDir"
RPMS="$(pwd)/RPMs"
SPT_URL="https://web.archive.org/web/20260405142525/
https://files.pythonhosted.org/packages/8f/71/
1017f29259f486f963535213b2b81645da35edd14de3539084e2d291d16b/
setproctitle-1.2.3-cp36-cp36m-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
# I archived it myself and calculated the hash when the wheel was still up

# Hashes
TARBALL_SHA256="171ddf7e216f12a9e0ed63cd0a97796fd63967df3b3aa5e452877b74aabd48c9"
PATCH_SHA256="c8fab9cd79c7def484809158930df576de5a6a4c08232272b3f8eed9ae18c874"
OPENMOJI_SHA256="af7a784e6a0dafb343c5e1958b159ca577c1faad6ab37add8a939f849f9a0303"
AIT_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
SPT_SHA256="b2fa9f4b382a6cf88f2f345044d0916a92f37cac21355585bd14bc7ee91af187"

# Clear old resources
rm -rf "$APPDIR" "$AIT_DIR" Emote-* RPMs "v${VERSION}.tar.gz" *.whl

###############################################
# Prepare OL8 repo and RPMs
###############################################

# Oracle Linux gives slightly smaller and newer binaries
# Otherwise Ellison can drown in boiling piss for all I care

ol8_key

tee /etc/yum.repos.d/ol8.repo > /dev/null << 'EOF'
[ol8_base]
name=Oracle Linux 8 Base
baseurl=https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/OL8
enabled=0

[ol8_epel]
name=Oracle Linux 8 EPEL
baseurl=https://yum.oracle.com/repo/OracleLinux/OL8/developer/EPEL/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/OL8
enabled=0

[ol8_appstream]
name=Oracle Linux 8 AppStream
baseurl=https://yum.oracle.com/repo/OracleLinux/OL8/appstream/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/OL8
enabled=0
EOF

mkdir -p "$RPMS"
pushd "$RPMS" >/dev/null

dnf download \
  --arch=x86_64 \
  --disablerepo="*" \
  --enablerepo=ol8_epel \
  libxdo \
  xdotool \
  python3-regex

dnf download \
  --arch=x86_64 \
  --disablerepo="*" \
  --enablerepo=ol8_base \
  libffi \
  openssl-libs \
  platform-python \
  python3-dbus \
  python3-gobject-base \
  python3-libs

dnf download \
  --arch=x86_64 \
  --disablerepo="*" \
  --enablerepo=ol8_appstream \
  keybinder3 \
  python3-cairo

popd >/dev/null

for rpm in "$RPMS"/*.rpm; do
    echo "Processing $rpm"

    # Create a temporary extraction directory
    TMPDIR=$(mktemp -d)

    # Extract RPM contents
    rpm2cpio "$rpm" | cpio -idmv -D "$TMPDIR"

    # Copy only the desired directories if they exist
    for path in usr/share/licenses usr/lib64 usr/libexec usr/bin; do
        if [ -d "$TMPDIR/$path" ]; then
            mkdir -p "$APPDIR/$path"
            cp -a "$TMPDIR/$path/." "$APPDIR/$path/"
        fi
    done

    # Clean up
    rm -rf "$TMPDIR"
done

echo "RPMs merged into AppDir"

# Remove OpenSSL 1.1 engines – not used in Python
rm -rf "$APPDIR/usr/lib64/engines-1.1"

# Ensure platform-python3.6m symlink exists
ln -sf "../libexec/platform-python3.6m" "$APPDIR/usr/bin/python3.6"

SITE_PACKAGES="$APPDIR/usr/lib64/python${PYVER}/site-packages"

# Remove the newline that split the URL
SPT_URL="${SPT_URL//$'\n'/}"

wget -O "setproctitle.whl" "$SPT_URL"
if echo "$SPT_SHA256  setproctitle.whl" | sha256sum -c -; then
    echo "setproctitle.whl checksum OK"
    unzip -j setproctitle*.whl "*.so" -d "$SITE_PACKAGES"
else
    echo "ERROR: Checksum mismatch!"
    exit 1
fi

###############################################
# Prepare sources
###############################################

wget -O "v${VERSION}.tar.gz" \
  "https://github.com/tom-james-watson/Emote/archive/refs/tags/v${VERSION}.tar.gz"

# Removes manimpango
wget -O 154.patch \
  "https://patch-diff.githubusercontent.com/raw/tom-james-watson/Emote/pull/154.patch"

if echo "$TARBALL_SHA256  v${VERSION}.tar.gz" | sha256sum -c - \
   && echo "$PATCH_SHA256  154.patch" | sha256sum -c -; then
    echo "Checksums OK – extracting and patching"
    tar xf "v${VERSION}.tar.gz"
    mv 154.patch "Emote-${VERSION}"
    pushd "Emote-${VERSION}" >/dev/null
    patch -p1 < 154.patch
else
    echo "ERROR: Checksum mismatch!"
    exit 1
fi

###############################################
# Apply quality of life patches
###############################################

picker_patch
patch -p1 < picker.patch
emojis_patch
patch -p1 < emojis.patch

# Copy emote module to AppDir
mkdir -p "$SITE_PACKAGES/emote"
cp -r emote/* "$SITE_PACKAGES/emote"

###############################################
# Static assets (CSS, icons, emojis)
###############################################

popd >/dev/null

STATIC_DIR="$SITE_PACKAGES/emote/static"
mkdir -p "$STATIC_DIR"

cp "Emote-${VERSION}/static/style.css" "$STATIC_DIR"
cp "Emote-${VERSION}/static/logo.svg" "$STATIC_DIR"

wget -O "$STATIC_DIR/openmoji.csv" \
  "https://raw.githubusercontent.com/hfg-gmuend/openmoji/refs/tags/16.0.0/data/openmoji.csv"

if echo "$OPENMOJI_SHA256  $STATIC_DIR/openmoji.csv" | sha256sum -c -; then
    echo "openmoji.csv checksum OK"
else
    echo "ERROR: Checksum mismatch!"
    exit 1
fi

perl -CSD -Mutf8 -i -pe '
  if (/([Tt][\x{DC}\x{FC}Uu][Rr][Kk][\x{130}Ii\x{131}][Yy][Ee])/u){
      $w = $1;
      $upper = ($w =~ tr/A-Z\x{DC}\x{130}//);
      $lower = ($w =~ tr/a-z\x{FC}\x{131}//);
      if ($w =~ /^[a-z]/u) {
          s/$w/turkey/;
      } elsif ($upper > $lower) {
          s/$w/TURKEY/;
      } else {
          s/$w/Turkey/;
      }
  }
' "$STATIC_DIR/openmoji.csv" # You ain't getting it, Erdoğan

cp "Emote-${VERSION}/static/com.tomjwatson.Emote.desktop" "$APPDIR/emote.desktop"
sed -i 's/Icon=.*/Icon=emote/' "$APPDIR/emote.desktop"
sed -i 's/Exec=.*/Exec=\/AppRun/' "$APPDIR/emote.desktop"
sed -i '/^Keywords=/ s/,/;/g' "$APPDIR/emote.desktop"

cp "Emote-${VERSION}/static/logo.svg" "$APPDIR/emote.svg"

mkdir -p "$APPDIR/usr/share/applications"
cp "$APPDIR/emote.desktop" "$APPDIR/usr/share/applications"

mkdir -p "$APPDIR/usr/share/icons/hicolor/scalable/apps"
cp "$APPDIR/emote.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps"

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
    cp "$ICON_SRC" "$ICON_DEST"

    mkdir -p "$DESKTOP_TARGET"
    cp "$DESKTOP_SRC" "$DESKTOP_TARGET"

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

PYDIR="$(ls "$HERE/usr/lib64" | grep -E '^python[0-9]+\.[0-9]+$' | head -n1)"
PYVER="${PYDIR#python}"

# Use only bundled binaries first
export PATH="$HERE/usr/bin:$PATH"

# Use only bundled GI typelibs first
export GI_TYPELIB_PATH="$HERE/usr/lib64/girepository-1.0"

# Use only bundled libs first
export LD_LIBRARY_PATH="$HERE/usr/lib64:${LD_LIBRARY_PATH:-}"

# Python environment
export PYTHONHOME="$HERE/usr"
export PYTHONPATH="$HERE/usr/lib64/python${PYVER}:$HERE/usr/lib64/python${PYVER}/site-packages:$HERE/usr/lib64/python${PYVER}/lib-dynload"
export PYTHONPLATLIBDIR="lib-dynload"

# Change directory for relative paths to work
cd "$HERE/usr/lib64/python${PYVER}/site-packages/emote"

echo "Running Emote from: $(pwd)"

exec "$HERE/usr/bin/python${PYVER}" __main__.py "$@"
EOF

chmod +x "$APPDIR/AppRun"

###############################################
# Fetch appimagetool dynamically
###############################################

APPIMAGETOOL="$AIT_DIR/appimagetool-x86_64.AppImage"
mkdir -p "$AIT_DIR"

if [ ! -f "$APPIMAGETOOL" ]; then
    echo "Downloading appimagetool..."
    wget -O "$APPIMAGETOOL" \
      "https://github.com/AppImage/appimagetool/releases/download/${AIT_VER}/appimagetool-x86_64.AppImage"

    if echo "$AIT_SHA256  $APPIMAGETOOL" | sha256sum -c -; then
        echo "appimagetool checksum OK"
        chmod +x "$APPIMAGETOOL"
    else
        echo "ERROR: Checksum mismatch!"
        exit 1
    fi
fi

###############################################
# Build AppImage
###############################################

RUNTIME="runtime-x86_64"

appimage_key

wget -O "$AIT_DIR/runtime-x86_64.sig" \
  "https://github.com/AppImage/type2-runtime/releases/download/continuous/$RUNTIME.sig"
wget -O "$AIT_DIR/runtime-x86_64" \
  "https://github.com/AppImage/type2-runtime/releases/download/continuous/$RUNTIME"

if gpg --verify "$AIT_DIR/$RUNTIME.sig" "$AIT_DIR/$RUNTIME" 2>/dev/null; then
    echo "Runtime signature OK"
    ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run --no-appstream --runtime-file "$AIT_DIR/$RUNTIME" "$APPDIR"
else
    echo "ERROR: Signature verification failed!"
    exit 1
fi

###############################################
# Cleanup
###############################################

shopt -s extglob
rm -rf "$APPDIR" "$AIT_DIR" Emote-!(*.AppImage) RPMs "v${VERSION}.tar.gz" *.whl

echo "Done"