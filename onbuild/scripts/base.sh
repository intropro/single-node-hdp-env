#!/bin/bash

SCRIPTNAME=$(readlink -f $0)
SCRIPTPATH=$(dirname ${SCRIPTNAME})

set -eo pipefail
[[ "${TRACE}" ]] && set -x -e || :

install_base_packages() {
    yum clean all && \
    yum install -y epel-release && \
    yum install -y \
        openssh-server \
        openssh-clients \
        sudo \
        tar \
        unzip \
        vim \
        wget \
        krb5-libs \
        krb5-workstation \
        net-tools \
        ntp \
        openldap-clients \
        python-pip \
        haveged \
        xmlstarlet \
        jq \
        nc \
        telnet \
        sshfs \
        mlocate \
        gcc \
        lsof && \
    yum clean all && \
    pip install -U pip && \
    easy_install supervisor

    # supervisod
    mkdir /var/log/supervisor /etc/supervisord.d
    cp /${SCRIPTPATH}/../configs/supervisord.conf /etc/
    cp /${SCRIPTPATH}/../configs/supervisord.d/ssh.conf /etc/supervisord.d/
    cp /${SCRIPTPATH}/../configs/supervisord.d/ntp.conf /etc/supervisord.d/
    cp /${SCRIPTPATH}/../configs/supervisord.d/haveged.conf /etc/supervisord.d/
    cp /${SCRIPTPATH}/../configs/supervisord.d/deploy.conf /etc/supervisord.d/
}

os_configure() {

    # Generate ssh keys
    ssh-keygen -b 1024 -t rsa -f /etc/ssh/ssh_host_key -q -N '' && \
    ssh-keygen -b 1024 -t rsa -f /etc/ssh/ssh_host_rsa_key -q -N '' && \
    ssh-keygen -b 1024 -t dsa -f /etc/ssh/ssh_host_dsa_key -q -N ''

    # Set timezone
    cp -rf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

    # Grant sudo rights
    sed -i 's/Defaults.*requiretty.*$/#Defaults requiretty/' /etc/sudoers
    sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers

    # Add default user
    useradd -G wheel ${DEFAULT_ENV_USER}; echo "${DEFAULT_ENV_USER}:${DEFAULT_ENV_PASSWORD}" | chpasswd

    # Set root password
    echo "root:${DEFAULT_ROOT_PASSWORD}" | chpasswd

    printf "export LC_ALL=${LC_ALL}\n\
export TERM=${TERM}\n\
" > /etc/profile.d/env.sh && chmod +x /etc/profile.d/env.sh

}

all() {
    install_base_packages
    os_configure
}

uninstall_base_packages() {
    echo "[ERROR] Not implemented"
    exit 1
}

$@