#!/bin/bash
# Reverse Linux VNC for GitHub Actions by PANCHO7532
# This script is executed when GitHub actions is initialized.
# Prepares dependencies, ngrok, and vnc stuff

# * 1, install required packages...
sudo apt update
sudo apt install -y xfce4 xfce4-goodies xfonts-base xubuntu-icon-theme xubuntu-wallpapers gnome-icon-theme x11-apps x11-common x11-session-utils x11-utils x11-xserver-utils x11-xkb-utils dbus-user-session dbus-x11 gnome-system-monitor gnome-control-center libpam0g libxt6 libxext6 > /dev/null 2>&1

# * 2, install TurboVNC
# Fun Fact: TurboVNC is the only VNC implementations that supports OpenGL acceleration without an graphics device by default
# By the way, you can still use the legacy version of this script where instead of installing TurboVNC, tightvncserver is installed.

if [ "$RUNNER_ARCH" == "ARM64" ]; then
    wget https://phoenixnap.dl.sourceforge.net/project/turbovnc/3.1/turbovnc_3.1_arm64.deb
    sudo dpkg -i turbovnc_3.1_arm64.deb

    wget https://bin.ngrok.com/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz
    tar xzf ngrok-v3-stable-linux-arm64.tgz
    chmod +x ngrok
else
    wget https://phoenixnap.dl.sourceforge.net/project/turbovnc/3.1/turbovnc_3.1_amd64.deb
    sudo dpkg -i turbovnc_3.1_amd64.deb

    wget https://bin.ngrok.com/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xzf ngrok-v3-stable-linux-amd64.tgz
    chmod +x ngrok
fi

# * 4, generate and copy passwd file and xstartup script
export PATH=$PATH:/opt/TurboVNC/bin
mkdir $HOME/.vnc
cp ./resources/xstartup $HOME/.vnc/xstartup.turbovnc
echo $VNC_PASSWORD | vncpasswd -f > $HOME/.vnc/passwd
chmod 0600 $HOME/.vnc/passwd

# * 5, set up auth token from argument
./ngrok config add-authtoken $NGROK_AUTH_TOKEN

# * 6, restore firefox profile
rm -rf ~/.mozilla
gpg --batch --yes --passphrase $VNC_PASSWORD --decrypt ./resources/ffb.tar.gz.gpg > ./resources/ffb.tar.gz
tar -xzf ./resources/ffb.tar.gz -C /

exit
