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
apt-get update
apt-get install -y --no-install-recommends git sassc libglib2.0-dev-bin ca-certificates
cd /tmp
git clone --depth 1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git
git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git
git clone --depth 1 https://github.com/vinceliuice/WhiteSur-cursors.git
( cd WhiteSur-gtk-theme  && ./install.sh -d /usr/share/themes -c Light -o normal -N glassy || ./install.sh -d /usr/share/themes )
( cd WhiteSur-icon-theme && ./install.sh -d /usr/share/icons )
( cd WhiteSur-cursors    && { ./install.sh || true; }; [ -d dist ] && cp -r dist /usr/share/icons/WhiteSur-cursors || true )
rm -rf /tmp/WhiteSur-*
apt-get purge -y git sassc libglib2.0-dev-bin
apt-get autoremove -y
apt-get clean
EOF

# ------------------------------------------------------------------ hook: ottimizzazioni
cat > config/hooks/normal/0200-tune.hook.chroot <<'EOF'
#!/bin/bash
set -e
chmod +x /usr/local/bin/macify-first-run
systemctl enable zramswap.service 2>/dev/null || true
for s in bluetooth.service ModemManager.service cups.service cups-browsed.service avahi-daemon.service \
         apt-daily.timer apt-daily-upgrade.timer man-db.timer; do
  systemctl disable "$s" 2>/dev/null || true
done
# Italiano di default
sed -i 's/^# *it_IT.UTF-8/it_IT.UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=it_IT.UTF-8
# Elimina documentazione e locale inutili per risparmiare spazio e RAM
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* 2>/dev/null || true
EOF
chmod +x config/hooks/normal/*.hook.chroot

# ------------------------------------------------------------------ configurazioni di sistema
cat > config/includes.chroot/etc/default/zramswap <<'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF

cat > config/includes.chroot/etc/sysctl.d/99-maclite.conf <<'EOF'
vm.swappiness=20
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
EOF

cat > config/includes.chroot/etc/lightdm/lightdm-gtk-greeter.conf <<'EOF'
[greeter]
theme-name=WhiteSur-Light
icon-theme-name=WhiteSur
font-name=Inter 10
cursor-theme-name=WhiteSur-cursors
EOF

# ------------------------------------------------------------------ configurazioni utente (/etc/skel)
SKEL=config/includes.chroot/etc/skel/.config

cat > "$SKEL/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="26"/>
      <property name="background-style" type="uint" value="0"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu">
      <property name="button-icon" type="string" value="start-here"/>
      <property name="show-button-title" type="bool" value="false"/>
    </property>
    <property name="plugin-2" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="systray"/>
    <property name="plugin-4" type="string" value="pulseaudio"/>
    <property name="plugin-5" type="string" value="power-manager-plugin"/>
    <property name="plugin-6" type="string" value="clock">
      <property name="digital-format" type="string" value="%a %e %b  %H:%M"/>
      <property name="mode" type="uint" value="2"/>
    </property>
  </property>
</channel>
EOF

cat > "$SKEL/autostart/plank.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Dock
Exec=plank
X-GNOME-Autostart-enabled=true
EOF

cat > "$SKEL/autostart/macify-first-run.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=MacLite first run
Exec=/usr/local/bin/macify-first-run
EOF

mk_item() { printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$2" > "$SKEL/plank/dock1/launchers/$1.dockitem"; }
mk_item 1-files    /usr/share/applications/thunar.desktop
mk_item 2-firefox  /usr/share/applications/firefox-esr.desktop
mk_item 3-terminal /usr/share/applications/xfce4-terminal.desktop
mk_item 4-text     /usr/share/applications/org.xfce.mousepad.desktop
mk_item 5-settings /usr/share/applications/xfce-settings-manager.desktop

cat > config/includes.chroot/usr/local/bin/macify-first-run <<'EOF'
#!/usr/bin/env bash
# Eseguito una sola volta al primo login grafico
set -u
x() { xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4" 2>/dev/null || xfconf-query -c "$1" -p "$2" -s "$4"; }

x xsettings /Net/ThemeName       string "WhiteSur-Light"
x xsettings /Net/IconThemeName   string "WhiteSur"
x xsettings /Gtk/CursorThemeName string "WhiteSur-cursors"
x xsettings /Gtk/FontName        string "Inter 10"
x xsettings /Xft/Antialias       int 1
x xsettings /Xft/HintStyle       string "hintslight"
x xsettings /Xft/RGBA            string "rgb"

x xfwm4 /general/theme               string "WhiteSur-Light"
x xfwm4 /general/title_font          string "Inter Bold 10"
x xfwm4 /general/button_layout       string "CHM|"
x xfwm4 /general/title_alignment     string "center"
x xfwm4 /general/use_compositing     bool false
x xfwm4 /general/double_click_action string "maximize"

dconf write /net/launchpad/plank/docks/dock1/theme "'Transparent'" 2>/dev/null || true
dconf write /net/launchpad/plank/docks/dock1/icon-size 48 2>/dev/null || true
dconf write /net/launchpad/plank/docks/dock1/hide-mode "'window-dodge'" 2>/dev/null || true

rm -f "$HOME/.config/autostart/macify-first-run.desktop"
EOF

# ------------------------------------------------------------------ build
echo "==> Costruisco l'ISO (puo' richiedere 20-40 minuti)"
lb build 2>&1 | tee build.log

ISO="$(ls -1 ./*.iso 2>/dev/null | head -n1 || true)"
[ -n "$ISO" ] || { echo "Build fallita: guarda $BUILD_DIR/build.log"; exit 1; }
mv "$ISO" "$OUT_ISO"
chown "${SUDO_USER:-root}":"${SUDO_USER:-root}" "$OUT_ISO" 2>/dev/null || true
sha256sum "$OUT_ISO"
echo
echo "Fatto: $OUT_ISO"
echo "Scrivila su chiavetta (min. 4 GB) con balenaEtcher, Rufus (modalita' DD) oppure:"
echo "  sudo dd if=$OUT_ISO of=/dev/sdX bs=4M status=progress conv=fsync"
