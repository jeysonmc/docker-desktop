# This file creates a container that runs X11 and SSH services
# The ssh is used to forward X11 and provide you encrypted data
# communication between the docker container and your local 
# machine.
#
# Xpra allows to display the programs running inside of the
# container such as Firefox, LibreOffice, xterm, etc. 
# with disconnection and reconnection capabilities
#
# Xephyr allows to display the programs running inside of the
# container such as Firefox, LibreOffice, xterm, etc. 
#
# Fluxbox and ROX-Filer creates a very minimalist way to 
# manages the windows and files.
#
# Author: Roberto Gandolfo Hashioka
# Date: 07/28/2013


FROM ubuntu:latest

RUN apt-get update -y
RUN apt-get install -y  libjpeg-dev cabextract rox-filer openssh-server pwgen xserver-xephyr xdm fluxbox xvfb sudo xterm


# Install some tools required for creating the image
RUN apt-get update -y \
	&& apt-get install -y --no-install-recommends \
		curl \
		unzip \
		software-properties-common \
	&& add-apt-repository ppa:ubuntu-wine/ppa

# Install wine and related packages
# Define which versions we need
ENV WINE_MONO_VERSION 4.5.6
ENV WINE_GECKO_VERSION 2.40

RUN dpkg --add-architecture i386 \
	&& apt-get update -y \
	&& apt-get install -y --no-install-recommends \
		wine1.7 \
		wine-gecko$WINE_GECKO_VERSION:i386 \
		wine-gecko$WINE_GECKO_VERSION:amd64 \
		wine-mono$WINE_MONO_VERSION \
	&& rm -rf /var/lib/apt/lists/*


# Use the latest version of winetricks
RUN curl -SL 'https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks' -o /usr/local/bin/winetricks \
		&& chmod +x /usr/local/bin/winetricks




RUN sudo apt-get update \
	&& sudo apt-get -y install --no-install-recommends software-properties-common curl \
	&& curl http://winswitch.org/gpg.asc | sudo apt-key add - \
	&& sudo sh -c 'echo "deb http://winswitch.org/ trusty main" > /etc/apt/sources.list.d/winswitch.list' \
	&& sudo add-apt-repository universe \
	&& sudo apt-get update \
	&& sudo apt-get -y install --no-install-recommends xpra xvfb \
	&& sudo apt-get clean \
	&& sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
# Set the env variable DEBIAN_FRONTEND to noninteractive
ENV DEBIAN_FRONTEND noninteractive

# Installing the environment required: xserver, xdm, flux box, roc-filer and ssh

# Configuring xdm to allow connections from any IP address and ssh to allow X11 Forwarding. 
RUN sed -i 's/DisplayManager.requestPort/!DisplayManager.requestPort/g' /etc/X11/xdm/xdm-config
RUN sed -i '/#any host/c\*' /etc/X11/xdm/Xaccess
RUN ln -s /usr/bin/Xorg /usr/bin/X
RUN echo X11Forwarding yes >> /etc/ssh/ssh_config

# Fix PAM login issue with sshd
RUN sed -i 's/session    required     pam_loginuid.so/#session    required     pam_loginuid.so/g' /etc/pam.d/sshd

# Upstart and DBus have issues inside docker. We work around in order to install firefox.
RUN dpkg-divert --local --rename --add /sbin/initctl && ln -sf /bin/true /sbin/initctl

# Installing fuse package (libreoffice-java dependency) and it's going to try to create
# a fuse device without success, due the container permissions. || : help us to ignore it. 
# Then we are going to delete the postinst fuse file and try to install it again!
# Thanks Jerome for helping me with this workaround solution! :)
# Now we are able to install the libreoffice-java package  

# Installing the apps: Firefox, flash player plugin, LibreOffice and xterm
# libreoffice-base installs libreoffice-java mentioned before

# Set locale (fix the locale warnings)
RUN localedef -v -c -i en_US -f UTF-8 en_US.UTF-8 || :

# Copy the files into the container
ADD . /src

EXPOSE 22
EXPOSE 54297
EXPOSE 64297
# TODO other ports to expose


# Create the directory needed to run the sshd daemon
RUN mkdir /var/run/sshd 

# Add docker user and generate a random password with 12 characters that includes at least one capital letter and number.
RUN useradd -m -d /home/docker  docker
RUN echo 'docker:docker' | chpasswd
RUN sed -Ei 's/adm:x:4:/docker:x:4:docker/' /etc/group
RUN adduser docker sudo

# Set the default shell as bash for docker user.
RUN chsh -s /bin/bash docker


# Start xdm and ssh services.
CMD ["/bin/bash", "/src/startup.sh"]
