#!/usr/bin/env bash
# build-iso.sh - Costruisce "MacLite", ISO avviabile a 32 bit (Debian 12 + Xfce in stile macOS)
# per portatili del 2010.
#
# REQUISITI: PC con Debian o Ubuntu (anche in VM), internet, ~15 GB liberi, privilegi sudo.
# USO:       sudo bash build-iso.sh
# RISULTATO: ./maclite-i386.iso  (scrivibile su chiavetta con balenaEtcher, Rufus o dd)

set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Esegui con: sudo bash build-iso.sh"; exit 1; }

BUILD_DIR="${BUILD_DIR:-$PWD/maclite-build}"
OUT_ISO="$PWD/maclite-i386.iso"

echo "==> Installo gli strumenti di build"
apt-get update
apt-get install -y live-build debootstrap xorriso squashfs-tools syslinux syslinux-utils isolinux \
  mtools dosfstools debian-archive-keyring ca-certificates git

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "==> Configuro live-build (i386, Debian 12 bookworm)"
lb config \
  --mode debian \
  --distribution bookworm \
  --architectures i386 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --linux-flavours "686 686-pae" \
  --binary-images iso-hybrid \
  --bootloaders "syslinux" \
  --debian-installer live \
  --debian-installer-gui false \
  --apt-recommends false \
  --apt-indices false \
  --security true --updates true \
  --iso-application "MacLite" \
  --iso-publisher "MacLite" \
  --iso-volume "MacLite" \
  --bootappend-live "boot=live components quiet username=maclite hostname=maclite locales=it_IT.UTF-8 keyboard-layouts=it timezone=Europe/Rome"

mkdir -p config/package-lists config/hooks/normal \
         config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml \
         config/includes.chroot/etc/skel/.config/autostart \
         config/includes.chroot/etc/skel/.config/plank/dock1/launchers \
         config/includes.chroot/etc/default \
         config/includes.chroot/etc/sysctl.d \
         config/includes.chroot/etc/lightdm \
         config/includes.chroot/usr/local/bin

# ------------------------------------------------------------------ pacchetti
cat > config/package-lists/maclite.list.chroot <<'EOF'
# Sistema grafico
xorg
xserver-xorg-video-intel
xserver-xorg-video-nouveau
xserver-xorg-video-ati
xserver-xorg-video-fbdev
# Desktop leggero
xfce4-session
xfwm4
xfce4-panel
xfce4-settings
xfdesktop4
xfce4-terminal
xfce4-power-manager
xfce4-pulseaudio-plugin
xfce4-whiskermenu-plugin
thunar
thunar-volman
gvfs
gvfs-backends
mousepad
ristretto
# Login e rete
lightdm
lightdm-gtk-greeter
network-manager
network-manager-gnome
# Dock, font, audio
plank
fonts-inter
fonts-noto-color-emoji
dconf-cli
pulseaudio
pavucontrol
policykit-1-gnome
gtk2-engines-murrine
# Prestazioni
zram-tools
preload
# Applicazioni
firefox-esr
firefox-esr-l10n-it
# Firmware (Wi-Fi e schede comuni nei portatili 2010)
firmware-linux-free
firmware-iwlwifi
firmware-atheros
firmware-realtek
firmware-brcm80211
firmware-b43-installer
# Lingua
locales
console-setup
keyboard-configuration
EOF

# ------------------------------------------------------------------ hook: tema WhiteSur
cat > config/hooks/normal/0100-theme.hook.chroot <<'EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
# Nel chroot USER non esiste e l'installer WhiteSur si ferma in silenzio senza queste variabili
export USER=root SUDO_USER=root LOGNAME=root HOME=/root
apt-get update
apt-get install -y --no-install-recommends git sassc libglib2.0-dev-bin libxml2-utils ca-certificates
cd /tmp
git clone --depth 1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git
git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git
git clone --depth 1 https://github.com/vinceliuice/WhiteSur-cursors.git
( cd WhiteSur-gtk-theme  && ./install.sh -d /usr/share/themes -c Light -o normal -N glassy )
( cd WhiteSur-icon-theme && ./install.sh -d /usr/share/icons )
( cd WhiteSur-cursors    && ./install.sh )
rm -rf /tmp/WhiteSur-*
