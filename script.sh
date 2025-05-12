#!/usr/bin/env bash

log_file="$HOME/init.log"
: > "$log_file"  # truncate or create

echo "AWS Init Script" | tee -a "$log_file"
echo "THIS SCRIPT WAS ONLY DESIGNED FOR AMAZON LINUX 2023 RUNNING BASH 4 OR HIGHER!"
echo "Making log..." | tee -a "$log_file"
echo "Setting variables..." | tee -a "$log_file"

bash_version="${BASH_VERSION:-}"
if [ -z "$bash_version" ]; then
  echo "Not running under Bash!" | tee -a "$log_file"
  exit 1
fi

major_version="${bash_version%%.*}"
minor_version="${bash_version#*.}"
minor_version="${minor_version%%.*}"

if [ "$major_version" -ge 4 ]; then
  echo "Running in Bash $bash_version!" | tee -a "$log_file"
else
  echo "Bash version $bash_version is less than 4, which this script doesn’t support." \
       | tee -a "$log_file"
  exit 1
fi
args="-y --skip-broken"
upgrade_args="-y --skip-broken --bugfix --enhancement --newpackage --security"
pip_args="--break-system-packages --log $log_file"
flatpak_args="-y --or-update --noninteractive"
echo "Starting..." | tee -a "$log_file"

check_updates()
{
	echo "Running check_updates()..." | tee -a "$log_file"
	cd "$HOME"
	# dnf check updates
	echo "Checking dnf updates..." | tee -a "$log_file"
	sudo dnf check-update "$upgrade_args" &>> "$log_file"
	sudo dnf upgrade "$upgrade_args" &>> "$log_file"
	# yum check updates
	echo "Checking yum updates..." | tee -a "$log_file"
	sudo yum check-update "$upgrade_args" &>> "$log_file"
	sudo yum upgrade "$upgrade_args" &>> "$log_file"
}

install_vnc()
{
	echo "Running install_vnc()..." | tee -a "$log_file"
	cd "$HOME"
	# install gnome
	echo "Installing and enabling GNOME... (this may take a while)" | tee -a "$log_file"
	sudo dnf groupinstall "Desktop" "$args" &>> "$log_file"
	sudo dnf install "$args" \
	  gnome-session gnome-shell \
	  mutter gnome-settings-daemon dbus-x &>> "$log_file"
	sudo systemctl enable --now gdm &>> "$log_file"
	# install tigervnc-server
	echo "Installing tigervnc-server..." | tee -a "$log_file"
	sudo dnf install tigervnc-server "$args" &>> "$log_file"
	# let user choose password
	echo "Choose a password for the VNC server:" | tee -a "$log_file"
	vncpasswd | tee -a "$log_file"
	echo "Appending /etc/tigervnc/vncserver.users..." | tee -a "$log_file"
	users_file="/etc/tigervnc/vncserver.users"
	echo ":1=ec2-user" | sudo tee -a "$users_file" &>> "$log_file"
	echo "Appending /etc/tigervnc/vncserver-config-defaults..." | tee -a "$log_file"
	config_file="/etc/tigervnc/vncserver-config-defaults"
	echo "session=gnome" | sudo tee -a "$config_file" &>> "$log_file"
	echo "securitytypes=vncauth,tlsvnc" | sudo tee -a "$config_file" &>> "$log_file"
	echo "geometry=1920x1080" | sudo tee -a "$config_file" &>> "$log_file"
	echo "localhost" | sudo tee -a "$config_file" &>> "$log_file"
	echo "alwaysshared" | sudo tee -a "$config_file" &>> "$log_file"
	echo "Enabling vncserver service..." | tee -a "$log_file"
	sudo systemctl enable --now vncserver@:1 &>> "$log_file"
	echo "Disabling the idle lockscreen..." | tee -a "$log_file"
	gsettings set org.gnome.desktop.session idle-delay 0 &>> "$log_file"
	# configure X server
	echo "Configuring X server..." | tee -a "$log_file"
	sudo systemctl set-default graphical.target &>> "$log_file"
	# vvv shits X server until reboot
	sudo systemctl isolate graphical.target &>> "$log_file"
	echo "Installing a couple things..." | tee -a "$log_file"
	sudo yum install glx-utils xorg-x11-drv-dummy "$args" &>> "$log_file"
	echo "Appending /etc/X11/xorg.conf..." | tee -a "$log_file"
	xorg_conf="/etc/X11/xorg.conf"
	echo "Section \"Device\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    Identifier \"DummyDevice\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    Driver \"dummy\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    Option \"UseEDID\" \"false\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    VideoRam 512000" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "EndSection" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "Section \"Monitor\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    Identifier \"DummyMonitor\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    HorizSync   5.0 - 1000.0" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    VertRefresh 5.0 - 200.0" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    Option \"ReducedBlanking\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "EndSection" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "Section \"Screen\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    Identifier \"DummyScreen\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    Device \"DummyDevice\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    Monitor \"DummyMonitor\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    DefaultDepth 24" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    SubSection \"Display\"" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "        Viewport 0 0" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "        Depth 24" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "        Virtual 4096 2160" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "    EndSubSection" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "EndSection" | sudo tee -a "$xorg_conf" &>> "$log_file"
	echo "" | sudo tee -a "$xorg_conf" &>> "$log_file"
	# restart X server
	echo "Restarting X server..." | tee -a "$log_file"
	sudo systemctl isolate multi-user.target &>> "$log_file"
	sudo systemctl isolate graphical.target &>> "$log_file"
	# install amazon DCV
	echo "Downloading Amazon DCV..." | tee -a "$log_file"
	sudo rpm --import https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY &>> "$log_file"
	# make sure we are in ~
	cd "$HOME"
	wget https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-amzn2023-x86_64.tgz &>> "$log_file"
	echo "Extracting Amazon DCV..." | tee -a "$log_file"
	tar -xvzf nice-dcv-amzn2023-x86_64.tgz &>> "$log_file"
	cd nice-dcv-*/
	echo "Installing Amazon DCV..." | tee -a "$log_file"
	sudo dnf install ./*.rpm dkms pulseaudio-utils "$args" &>> "$log_file"
	echo "Please setup dkms:" | tee -a "$log_file"
	sudo dcvusbdriverinstaller | tee -a "$log_file"
}

setup_timezone()
{
	echo "Running setup_timezone()..." | tee -a "$log_file"
	cd "$HOME"
	# vvv too scary
	#echo "Erasing NTP..." | tee -a "$log_file"
	#sudo yum erase "$args" 'ntp*' &>> "$log_file"
	echo "Setting timezone..." | tee -a "$log_file"
	sudo timedatectl set-timezone Europe/London &>> "$log_file"
	echo "Installing chrony..." | tee -a "$log_file"
	sudo yum install chrony &>> "$log_file"
	echo "Configuring chrony..." | tee -a "$log_file"
	chrony_conf="/etc/chrony.conf"
	echo "server fd00:ec2::123 prefer iburst minpoll 4 maxpoll 4" | sudo tee -a "$chrony_conf" &>> "$log_file"
	echo "server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4" | sudo tee -a "$chrony_conf" &>> "$log_file"
	echo "server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4" | sudo tee -a "$chrony_conf" &>> "$log_file"
	echo "pool time.aws.com iburst" | sudo tee -a "$chrony_conf" &>> "$log_file"
	echo "Enabling chrony..." | tee -a "$log_file"
	sudo systemctl enable --now chronyd &>> "$log_file"
	echo "Reloading chrony..." | tee -a "$log_file"
	sudo service chronyd force-reload &>> "$log_file"
	echo "Restarting chrony..." | tee -a "$log_file"
	sudo service chronyd restart &>> "$log_file"
	sudo chkconfig chronyd on &>> "$log_file"
}

# neofetch yayyy
install_neofetch()
{
	echo "Running install_neofetch()..." | tee -a "$log_file"
	cd /opt
	echo "Downloading neofetch... (yay!)" | tee -a "$log_file"
	sudo git clone https://github.com/dylanaraps/neofetch.git &>> "$log_file"
	cd neofetch
	echo "Building and installing neofetch..." | tee -a "$log_file"
	sudo make install &>> "$log_file"
}

install_apache()
{
	echo "Running install_apache()..." | tee -a "$log_file"
	cd "$HOME"
	echo "Installing a couple things..." | tee -a "$log_file"
	sudo dnf install "$args" httpd mod_ssl \
	  php php-mysqlnd php-cli php-gd php-xml php-mbstring \
	  php-opcache certbot python3-certbot-apache python3-venv python3-pip wget &>> "$log_file"
	echo "Setting up certbot venv..." | tee -a "$log_file"
	sudo python3 -m venv /opt/certbot/ &>> "$log_file"
	sudo /opt/certbot/bin/pip install --upgrade pip &>> "$log_file"
	echo "Installing certbot..." | tee -a "$log_file"
	sudo /opt/certbot/bin/pip install certbot certbot-dns-cloudflare &>> "$log_file"
	sudo ln -s /opt/certbot/bin/certbot /usr/bin/certbot &>> "$log_file"
	echo 'export PATH=/opt/certbot/bin:$PATH' | sudo tee /etc/profile.d/certbot.sh &>> "$log_file"
	source /etc/profile.d/certbot.sh &>> "$log_file"
}

tailscale_directory_exists()
{
	echo "Running tailscale_directory_exists()..." | tee -a "$log_file"
	cd "$HOME"
	sudo touch /etc/sysctl.d/99-tailscale.conf
	echo "Appending /etc/sysctl.d/99-tailscale.conf..." | tee -a "$log_file"
	echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf &>> "$log_file"
	echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf &>> "$log_file"
	sudo sysctl -p /etc/sysctl.d/99-tailscale.conf &>> "$log_file"
}
tailscale_directory_noexist()
{
	echo "Running tailscale_directory_noexist()..." | tee -a "$log_file"
	cd "$HOME"
	echo "Appending /etc/sysctl.conf..." | tee -a "$log_file"
	echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf &>> "$log_file"
	echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf &>> "$log_file"
	sudo sysctl -p /etc/sysctl.conf &>> "$log_file"
}

install_tailscale()
{
	echo "Running install_tailscale()..." | tee -a "$log_file"
	cd "$HOME"
	echo "Installing tailscale..." | tee -a "$log_file"
	curl -fsSL https://tailscale.com/install.sh | sh &>> "$log_file"
	echo "Setting up tailscale ip_foward..." | tee -a "$log_file"
	[ -d "/etc/sysctl.d" ] && tailscale_directory_exists || tailscale_directory_noexist
	read -r -p "Type in your Tailscale AWS VM auth key: (use https://login.tailscale.com/admin/machines/new-aws)\n" auth_key
	read -r -p "Type in the route to advertise: (typically 10.0.0.0/20)\n(Leave blank to advertise none)\n" routes
	routes=${routes:-""}
	echo "Starting tailscale..." | tee -a "$log_file"
	tailscale up --ssh --advertise-exit-node --advertise-routes="$routes" --auth-key="$auth_key" &>> "$log_file"
	echo "Configuring tailscale..." | tee -a "$log_file"
	tailscale set --exit-node-allow-lan-access --accept-routes --auto-update --webclient &>> "$log_file"
	echo "Restarting tailscale..." | tee -a "$log_file"
	tailscale down &>> "$log_file"
	tailscale up &>> "$log_file"
}

install_ncdu()
{
	echo "Running install_ncdu()..." | tee -a "$log_file"
	ncdu_version="2.8.2"
	read -r -p "Enter the latest ncdu version (.tar.gz download link)\n(Leave blank to use version $ncdu_version)\n" ncdu_version
	echo "Downloading ncdu $ncdu_version..." | tee -a "$log_file"
	cd /opt
	wget "https://dev.yorhel.nl/download/ncdu-$ncdu_version.tar.gz" &>> "$log_file"
	echo "Extracting ncdu $ncdu_version..." | tee -a "$log_file"
	tar -xvzf "ncdu-$ncdu_version.tar.gz" &>> "$log_file"
	cd "ncdu-$ncdu_version"
	echo "Building and installing ncdu $ncdu_version..." | tee -a "$log_file"
	./configure --prefix=/usr &>> "$log_file"
	make &>> "$log_file"
	sudo make install &>> "$log_file"
}

make_swap()
{
	echo "Running make_swap()..." | tee -a "$log_file"
	cd /
	swap_size="256G"
	read -r -p "Enter how much swap space to be allocated (enter the number and G at the end for GB)\n(Leave blank to use size $swap_size)\n" swap_size
	echo "Allocatting swap..." | tee -a "$log_file"
	swap_location="/swapfile"
	sudo fallocate -l "$swap_size" "$swap_location" &>> "$log_file"
	sudo chmod 600 "$swap_location" &>> "$log_file"
	sudo mkswap "$swap_location" &>> "$log_file"
	sudo swapon "$swap_location" &>> "$log_file"
	read -r -p "Choose your \"swappiness\": (recommended: 80)\n(You can change this anytime later.)\n" swappiness
	swappiness=${swappiness:-80}
	echo "Setting swappiness..." | tee -a "$log_file"
	sudo sysctl vm.swappiness="$swappiness" &>> "$log_file"
	echo "vm.swappiness=$swappiness" | sudo tee /etc/sysctl.d/99-swappiness.conf &>> "$log_file"
}

install()
{
	echo "Running install()..." | tee -a "$log_file"
	cd "$HOME"
	echo "Checking for updates..." | tee -a "$log_file"
	check_updates
	echo "Setting up timezone..." | tee -a "$log_file"
	setup_timezone
	echo "Importing VSCode key..." | tee -a "$log_file"
	sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc &>> "$log_file"
	echo -e "[code]
	name=Visual Studio Code
	baseurl=https://packages.microsoft.com/yumrepos/vscode
	enabled=1
	autorefresh=1
	type=rpm-md
	gpgcheck=1
	gpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
	  | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null 2>> "$log_file"
	echo "Importing Sublime Text key..." | tee -a "$log_file"
	sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg &>> "$log_file"
	sudo dnf config-manager --add-repo https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo &>> "$log_file"
 	# dosent work
	#echo "Enabling correto8 repo..." | tee -a "$log_file"
	#sudo amazon-linux-extras enable corretto8 &>> "$log_file"
	echo "Checking for updates..." | tee -a "$log_file"
	check_updates
	echo "Installing tools... (this may take a while)" | tee -a "$log_file"
	sudo dnf install git curl vim htop unzip zip nodejs nodejs-npm nodejs20 nodejs20-npm python3 python3-pip python3.12 python3.12-pip code sublime-text gcc make ncurses-devel flatpak firefox java-1.8.0-amazon-corretto-devel java-11-amazon-corretto-devel java-17-amazon-corretto-devel java-21-amazon-corretto-devel java-23-amazon-corretto-devel java-24-amazon-corretto-devel snapd "$args" &>> "$log_file"
	sudo dnf swap gnupg2-minimal gnupg2-full "$args" &>> "$log_file"
	echo "Setting up flatpack..." | tee -a "$log_file"
	sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>> "$log_file"
	echo "Installing a couple things..." | tee -a "$log_file"
	sudo flatpak install "$flatpak_args" flathub org.gnome.baobab &>> "$log_file"
	sudo flatpak install "$flatpak_args" flathub com.valvesoftware.Steam &>> "$log_file"
	echo "Enabling snapcraft (snapd)..." | tee -a "$log_file"
	sudo systemctl enable --now snapd.socket &>> "$log_file"
	sudo ln -s /var/lib/snapd/snap /snap &>> "$log_file"
	echo "Updating pip..." | tee -a "$log_file"
	# may fail, but it dosent mean its broken
	sudo pip install "$pip_args" --upgrade pip &>> "$log_file"
	echo "Installing a couple things..." | tee -a "$log_file"
	# i think this should work?
	sudo pip install "$pip_args" botocore boto3 &>> "$log_file"
	echo "Checking for updates..." | tee -a "$log_file"
	check_updates
	echo "Installing VNC and Amazon DCV... (this may take a while)" | tee -a "$log_file"
	install_vnc
	echo "Installing tailscale..." | tee -a "$log_file"
	install_tailscale
	echo "Installing ncdu..." | tee -a "$log_file"
	install_ncdu
	echo "Installing neofetch..." | tee -a "$log_file"
	install_neofetch
	echo "Checking for updates..." | tee -a "$log_file"
	check_updates
	echo "Finishing up..." | tee -a "$log_file"
	sleep 1 > /dev/null 2>> "$log_file"
}

ask_restart()
{
	cd "$HOME"
	read -r -p "Do you want to restart now? (Y/n)\n" restart_response
	restart_response=${restart_response:-Y}
	case "$restart_response" in
	  [Yy]* )
		echo "Restarting..." | tee -a "$log_file"
	    sudo reboot  # User answered Y or pressed Enter (default Y)
	    ;;
	  * )
	    echo "Exiting... Goodbye!" | tee -a "$log_file"
	    exit 1       # Any other answer → exit with code 1
	    ;;
	esac
}

cd "$HOME"
install
echo "Done! Check logs file at $log_file for more info" | tee -a "$log_file"
ask_restart
