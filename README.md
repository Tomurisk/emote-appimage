![GitHub License](https://img.shields.io/github/license/Tomurisk/emote-appimage)
# Additional packages to install on your system
X11: xdotool is already bundled

Wayland: `wl-copy ydotool`

# Application menu (un)registration
Run the AppImage in command line with argument `--reg` or `-r` to create the desktop file and associated icon

Run the AppImage in command line with argument `--unreg` or `-u` to remove them

# Help, some emojis are too wide!
Your version of Pango, the library that renders text in GTK, doesn't support the version of Unicode `openmoji.csv` file was defined in.

The easiest solution would be checking when was your distro released, and downloading `openmoji.csv` of around that date, then placing it into `~/.config` saved exactly as `openmoji.csv`.

Emoji data is sourced from https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/data/openmoji.csv

# Tested distros
<img src="https://upload.wikimedia.org/wikipedia/commons/7/7b/Ubuntu-logo-no-wordmark-solid-o-2022.svg" width="20"> Ubuntu 18.10

<img src="https://upload.wikimedia.org/wikipedia/commons/6/66/Openlogo-debianV2.svg" width="20"> Debian 10

<img src="https://upload.wikimedia.org/wikipedia/commons/6/63/CentOS_color_logo.svg" width="20"> CentOS 8

<img src="https://upload.wikimedia.org/wikipedia/commons/4/41/Fedora_icon_(2021).svg" width="20"> Fedora 35

<img src="https://upload.wikimedia.org/wikipedia/commons/d/d1/OpenSUSE_Button.svg" width="20"> openSUSE Leap 15.5

<img src="https://upload.wikimedia.org/wikipedia/commons/c/c9/Antu_distributor-logo-mageia.svg" width="20"> Mageia 7.1

<img src="https://upload.wikimedia.org/wikipedia/commons/3/3f/Linux_Mint_logo_without_wordmark.svg" width="20"> Linux Mint 22.3 Zena

<img src="https://upload.wikimedia.org/wikipedia/commons/4/41/Fedora_icon_(2021).svg" width="20"> Fedora 43

<img src="https://upload.wikimedia.org/wikipedia/commons/f/ff/Solus.svg" width="20"> Solus 2025-11-29

<img src="https://upload.wikimedia.org/wikipedia/commons/0/02/Void_Linux_logo.svg" width="20"> Void Linux 20250202

<img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/endeavouros-linux.svg" width="20"> EndeavourOS Ganymede Neo

# Credits
![GitHub License](https://img.shields.io/github/license/tom-james-watson/Emote)

Emote is a modern emoji picker for Linux, created by Tom J. Watson.
Copyright © Tom J. Watson.

Emote is licensed under the GNU General Public License, version 3.0 (GPL‑3.0).
You can find the full license text at: https://www.gnu.org/licenses/gpl-3.0.html

This AppImage includes the Emote Python module from the upstream project, which is also licensed under GPL‑3.0. Patches included or/and referenced in the script are also subjected to GPL‑3.0 license.

Source code is available at: https://github.com/tom-james-watson/Emote

## Other components
This AppImage bundles multiple third‑party components, each under its own license. The license of this project applies only to the project's own source code and does not cover the AppImage as a whole. Because the AppImage combines software under different and potentially incompatible licenses, it should be treated as a convenience artifact rather than a redistributable package. Anyone modifying or redistributing it should review the licenses of all bundled components to ensure compliance.