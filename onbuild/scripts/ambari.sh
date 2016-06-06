#!/bin/bash
SCRIPTNAME=$(readlink -f $0)
SCRIPTPATH=$(dirname ${SCRIPTNAME})

set -eo pipefail
[[ "$TRACE" ]] && set -x || :

set_repos() {

    if [[ "${USE_LOCAL_REPOSITORIES}" == "true" ]]
        then
            cat > /etc/yum.repos.d/hdp.repo << EOF
[HDP-${HDP_VERSION}]
name=HDP Version - HDP-${HDP_VERSION}
baseurl=http://${LOCAL_REPOSITORY_URL}/hdp/centos6/HDP-${HDP_VERSION}
gpgcheck=0
enabled=1
priority=1


[HDP-UTILS-${HDP_UTILS_VERSION}]
name=HDP Utils Version - HDP-UTILS-${HDP_UTILS_VERSION}
baseurl=http://${LOCAL_REPOSITORY_URL}/hdp/centos6/HDP-UTILS-${HDP_UTILS_VERSION}
gpgcheck=0
enabled=1
priority=1
EOF

            cat > /etc/yum.repos.d/ambari.repo << EOF
[Updates-ambari-${AMB_VERSION}]
name=ambari-${AMB_VERSION} - Updates
baseurl=http://${LOCAL_REPOSITORY_URL}/ambari/centos6/Updates-ambari-${AMB_VERSION}
gpgcheck=0
enabled=1
priority=1
EOF
        else
            wget -O /etc/yum.repos.d/ambari.repo http://public-repo-1.hortonworks.com/ambari/centos6/2.x/updates/${AMB_VERSION}/ambari.repo && cat /etc/yum.repos.d/ambari.repo
            wget -O /etc/yum.repos.d/hdp.repo http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/${HDP_VERSION}/hdp.repo && cat /etc/yum.repos.d/hdp.repo
    fi
}

install_server() {
    yum -y install ambari-server
    cp ${SCRIPTPATH}/../configs/supervisord.d/ambari-server.conf /etc/supervisord.d/
}

install_agent() {
    yum -y install ambari-agent
    cp ${SCRIPTPATH}/../configs/supervisord.d/ambari-agent.conf /etc/supervisord.d/
    ambari-server setup -j /usr/java/default -s
}

install_hue() {
    yum -y install hue
    # yum -y install python-devel postgresql-devel
}

install_web_info() {
    mv ${SCRIPTPATH}/hdp-env-config.py /usr/local/bin/
    cp ${SCRIPTPATH}/../configs/supervisord.d/web-info.conf /etc/supervisord.d/
}

all() {
    install_server
    install_agent
    install_hue
    install_web_info
}

yum clean all
# set_env
set_repos

$@