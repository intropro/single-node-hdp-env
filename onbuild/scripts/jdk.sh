#!/bin/bash
SCRIPTNAME=$(readlink -f $0)
SCRIPTPATH=$(dirname $SCRIPTNAME)

set -eo pipefail
[[ "$TRACE" ]] && set -x || :

JDK_VERSION=1.7.0_80
JDK_DOWNLOAD_PATH=http://download.oracle.com/otn-pub/java/jdk/7u80-b15/jdk-7u80-linux-x64.rpm
JCE_POLICY_DOWNLOAD_PATH=http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip


install() {
    # jdk install
    wget --progress=dot:giga -O /tmp/jdk-$JDK_VERSION-x64.rpm \
        --no-check-certificate -c \
        --header "Cookie: oraclelicense=accept-securebackup-cookie" \
        $JDK_DOWNLOAD_PATH && \
        yum -y localinstall /tmp/jdk-$JDK_VERSION-x64.rpm && \
        rm -f /tmp/jdk-$JDK_VERSION-x64.rpm
    # Install unlimited security policy for JAVA
    wget --progress=dot:giga -O /tmp/JCE.zip --no-check-certificate -c \
        --header "Cookie: oraclelicense=accept-securebackup-cookie" \
        $JCE_POLICY_DOWNLOAD_PATH && \
        unzip -d /tmp/ /tmp/JCE.zip && \
        cp -vf /tmp/UnlimitedJCEPolicy/US_export_policy.jar /usr/java/jdk$JDK_VERSION/jre/lib/security/ && \
        cp -vf /tmp/UnlimitedJCEPolicy/local_policy.jar /usr/java/jdk$JDK_VERSION/jre/lib/security/ && \
        rm -rf /tmp/*
    }

update_alternatives() {
    cp $SCRIPTPATH/java_alternatives_update.sh /usr/local/bin/
    /usr/local/bin/java_alternatives_update.sh
}

all() {
    install
    update_alternatives
}
$@