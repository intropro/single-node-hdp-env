#! /usr/bin/env bash

SCRIPTNAME=$(readlink -f $0)
SCRIPTPATH=$(dirname $SCRIPTNAME)

[[ "$TRACE" ]] && set -x || :

source /etc/profile.d/env.sh

FIRSTRUNFLAG="/var/lib/.ambari-deployed"

set_env() {
    printf "export AMB_ADMIN=${AMB_ADMIN}\n\
export AMB_ADMIN_PASSWORD=${AMB_ADMIN_PASSWORD}\n\
export AMB_VERSION=${AMB_VERSION}\n\
export HDP_CLUSTER_NAME=${HDP_CLUSTER_NAME}\n\
export HDP_VERSION=${HDP_VERSION}\n\
export HDP_UTILS_VERSION=${HDP_UTILS_VERSION}\n\
export HDP_STACK=${HDP_STACK}\n\
export LOCAL_REPOSITORY_URL=${LOCAL_REPOSITORY_URL}\n\
export KERBERIZED=${KERBERIZED}\n\
" > /etc/profile.d/amb.sh && chmod +x /etc/profile.d/amb.sh
source /etc/profile.d/amb.sh
}

ensure_user_is_root() {
    if [[ "$EUID" -ne "0" ]]; then
        echo "You must run this script as root. Try 'sudo ${0} ${@}'."
        exit 1
    fi
}

log() {
    echo -e "\033[1;32m[$(date +"%T")][docker-hdp-env] ${1}\033[0m"
}


waitdb() {
    c=0
    stat=1
    while [[ "$stat" == "1" ]]
        do
            log "Waiting for postgres to be started"
            sleep 5
            nc -z localhost 5432
            stat=$?
            c=$(($c+1))
            [[ $c == 20 ]] && {
                log "postgres is not running"
                exit 1
                }
        done
    
    [[ -z "$(service postgresql status | grep "is running")" ]] && {
        log "postgres is not running"
        exit 1
        }

}

waitamb() {
    nc -z $(hostname -f) 8080

    while [[ "$?" == "1" ]]
        do
            log "Waiting for Ambari to be started"
            sleep 5
            nc -z $(hostname -f) 8080
        done
    echo DONE
}

create_svc_db() {

    waitdb
    
    log "Create oozie db"
    echo "CREATE DATABASE oozie;" | sudo -u postgres psql -U postgres
    echo "CREATE USER oozie WITH PASSWORD '${DEFAULT_ENV_PASSWORD}';" | sudo -u postgres psql -U postgres
    echo "GRANT ALL PRIVILEGES ON DATABASE oozie TO oozie;" | sudo -u postgres psql -U postgres

    log "Create hive db"
    echo "CREATE DATABASE hive;" | sudo -u postgres psql -U postgres
    echo "CREATE USER hive WITH PASSWORD '${DEFAULT_ENV_PASSWORD}';" | sudo -u postgres psql -U postgres
    echo "GRANT ALL PRIVILEGES ON DATABASE hive TO hive;" | sudo -u postgres psql -U postgres

    # log "Create hue db"
    # echo "CREATE DATABASE hue;" | sudo -u postgres psql -U postgres
    # echo "CREATE USER hue WITH PASSWORD '${DEFAULT_ENV_PASSWORD}';" | sudo -u postgres psql -U postgres
    # echo "GRANT ALL PRIVILEGES ON DATABASE hue TO hue;" | sudo -u postgres psql -U postgres
}

configure_postgres_db() {
    log "Setup postgresql driver"
    ambari-server setup --jdbc-db=postgres --jdbc-driver=/usr/lib/ambari-server/postgresql-9.3-1101-jdbc4.jar

    log "Grant access to db from all sources"
    echo 'host  all   all  0.0.0.0/0  md5' >> /var/lib/pgsql/data/pg_hba.conf
    sudo -u postgres pg_ctl reload -s -D /var/lib/pgsql/data
}

deploy_hue() {
    log "Deploy hue"
    cp ${SCRIPTPATH}/configs/hue/hue_simple.ini.tmpl /etc/hue/conf/hue.ini
    if [[ "${KERBERIZED}" == "true" ]]
        then
            log "Deploy kerberized hue config"
            cp ${SCRIPTPATH}/configs/hue/hue_kerberized.ini.tmpl /etc/hue/conf/hue.ini
            log "Generate keytabs for hue"
            kadmin -p admin/admin -w ${DEFAULT_ENV_PASSWORD} -q "addprinc -randkey hue/$(hostname -f)"
            kadmin -p admin/admin -w ${DEFAULT_ENV_PASSWORD} -q "xst -k /etc/security/keytabs/hue.service.keytab hue/$(hostname -f)"
            chown hue:hadoop /etc/security/keytabs/hue.service.keytab
            chmod 400 /etc/security/keytabs/hue.service.keytab
    fi
    sed -i "s/<HOSTNAME_PLACE_HOLDER>/$(hostname -f)/g" /etc/hue/conf/hue.ini
    cp ${SCRIPTPATH}/configs/hue/hue_supervisor.conf  /etc/supervisord.d/hue.conf
    supervisorctl reread
    supervisorctl update
    supervisorctl start hue
}

configure_hadoop_env() {
    log "Make firtsboot changes"
    [[ "${KERBERIZED}" == "true" ]] && sudo -u hdfs kinit -kt /var/run/cloudera-scm-agent/process/*-hdfs-NAMENODE/hdfs.keytab hdfs/`hostname -f`

    sudo -u hdfs hdfs dfs -mkdir /data; sudo -u hdfs hdfs dfs -chmod 777 /data
    sudo -u hdfs hdfs dfs -mkdir /app; sudo -u hdfs hdfs dfs -chmod 777 /app
    
}

deploy_services_from_templates() {
    ${SCRIPTPATH}/templates.sh deploy_all
}

start_all_services() {
    ${SCRIPTPATH}/templates.sh start_all_services
}

deploy_all() {
    if [[ ! -e ${FIRSTRUNFLAG} ]]
        then
            log "Start first time deploy"
            touch ${FIRSTRUNFLAG}
            echo "Start time: $(date)" > /tmp/deploy_time.txt
            set_env
            waitamb
            configure_postgres_db
            create_svc_db
            [[ "${DEPLOY_HDP_SERVICES}" == "true" ]] && deploy_services_from_templates
            deploy_hue
            configure_hadoop_env
            ${SCRIPTPATH}/logo.sh
            log "Information for further setup:"
            echo "Cluster node hostname is $(hostname -f)"
            echo "Finish time: $(date)" >> /tmp/deploy_time.txt
            cat /tmp/deploy_time.txt
        else
            waitamb
            log "Start all services"
            start_all_services
            ${SCRIPTPATH}/logo.sh
    fi
}

ensure_user_is_root

$@