# Start from Ubuntu 22.04

FROM ubuntu:22.04

# Avoid interactive prompts during package installations

#ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages for adding a user and general utilities

RUN apt-get update && apt install -y net-tools wget python3.11 python3-pip python3-dev python3-venv bash-completion lzma xz-utils libgnutls28-dev swig uuid-dev flex bison build-essential git libssl-dev libffi-dev libmpc-dev device-tree-compiler bc gdisk kmod libncurses-dev curl \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y python3-pip python3-venv python3-setuptools python3-wheel

# Upgrade pip and install all required Python packages system-wide
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    python3 -m pip install cryptography pyelftools yamllint jsonschema setuptools-scm pycrypto

RUN apt-get update && apt install -y bsdmainutils chrpath cpio diffstat gawk gcc-multilib

RUN apt-get update && apt install -y git-lfs iputils-ping libegl1-mesa libsdl1.2-dev libusb-1.0-0 

#RUN apt-get update && apt install -y pylint python3-git python3-jinja2

RUN apt-get update && apt-get install -y  lz4  python3-pexpect socat texinfo unzip xterm zstd file libparted-dev

RUN apt-get update && apt-get install -y coreutils sed curl lrzsz corkscrew cvs subversion mercurial nfs-common nfs-kernel-server libarchive-zip-perl dos2unix texi2html libxml2-utils

RUN apt-get clean && apt-get update && apt-get install -y locales  libncurses5 libyaml-dev rsync

RUN locale-gen en_US.UTF-8

RUN sudo apt-get install -y dosfstools git kpartx wget tree parted fdisk nano

# Create a user with the same UID and GID as the host user
ARG USERNAME
ARG USER_UID
ARG USER_GID

RUN if getent group $USER_GID; then \
    EXISTING_GROUP=$(getent group $USER_GID | cut -d: -f1); \
    echo "Using existing group $EXISTING_GROUP with GID $USER_GID"; \
    else \
    groupadd --gid $USER_GID $USERNAME; \
    fi && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set the default user
USER $USERNAME
ENV PROJECT_HOME=/home/$USERNAME/frdm-ubuntu
ENV PATH="/home/${USERNAME}/.bin:${PATH}"

RUN mkdir -p ~/.bin && curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo && chmod a+rx ~/.bin/repo

RUN git config --global user.email "you@example.com"
RUN git config --global user.name "Your Name"

# Set working directory
WORKDIR $PROJECT_HOME
