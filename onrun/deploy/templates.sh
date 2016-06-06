#! /usr/bin/env bash

SCRIPTNAME=$(readlink -f $0)
SCRIPTPATH=$(dirname ${SCRIPTNAME})
TEMPLATES_DIR=${SCRIPTPATH}/templates
BLUEPRINT_TEMPLATE_FILENAME=blueprint.json.tmpl
CLUSTER_TEMPLATE_FILENAME=cluster.json.tmpl
HDP_REPO_TEMPLATE_FILENAME=hdp-repo.json.tmpl
HDPUTILS_REPO_TEMPLATE_FILENAME=hdp-utils-repo.json.tmpl
BLUEPRINT_FILENAME=blueprint.json
CLUSTER_FILENAME=cluster.json
HDP_REPO_FILENAME=hdp-repo.json
HDPUTILS_REPO_FILENAME=hdp-utils-repo.json
KERBEROS_CONFIG_TEMPLATE_FILENAME=kerberos_config.json.tmpl
KERBEROS_CONFIG_FILENAME=kerberos_config.json
KERBEROS_DESCRIPTOR_TEMPLATE_FILENAME=kerberos_descriptor.json.tmpl
KERBEROS_DESCRIPTOR_FILENAME=kerberos_descriptor.json
KERBEROS_CRED_TEMPLATE_FILENAME=kerberos_cred.json.tmpl
KERBEROS_CRED_FILENAME=kerberos_cred.json
# [[ "${TRACE}" ]] && set -x || :

source /etc/profile.d/env.sh
source /etc/profile.d/amb.sh

AMB_HOST=${AMB_HOST:-$(hostname -f)}
# For container that has different hostname to host's hostname
AMB_HOST_INT=${AMB_HOST_INT:-${AMB_HOST}}
REALM=${REALM:-BIGDATA}
KDC_SERVER=${KDC_SERVER:-kerberos}
# KRB_ADMIN_PRINCIPAL=${KRB_ADMIN_PRINCIPAL:-admin/admin@BIGDATA}
# KRB_ADMIN_PRINCIPAL_PASSWORD=${KRB_ADMIN_PRINCIPAL_PASSWORD:-bigdata}

log() {
    echo -e "\033[1;32m[$(date +"%T")][docker-hdp-env] ${1}\033[0m"
}

log_progress() {
    printf "\033[1;32m[$(date +"%T")][docker-hdp-env] ${1%.*} \033[0m\n"
}

check_status() {
    local JOB_ID=$1
    local PROGRESS_PCT=0
    local PREVIOUS_PROGRESS_PCT=0
    if [[ ( -z "${JOB_ID}" ) || ( "${JOB_ID}" == "null" ) ]]
        then
            log "FAIL to check JOB status because JOB_ID = null"
        else    
            PROGRESS_PCT=$(curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X GET http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/requests/${JOB_ID} | jq -r ". | .Requests | .progress_percent")
            log_progress "Current progrss = ${PROGRESS_PCT}"
            while [[ ! "$(curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X GET http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/requests/${JOB_ID} | jq -r ". | .Requests | .request_status")" == "COMPLETED" ]]
                do
                    PROGRESS_PCT=$(curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X GET http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/requests/${JOB_ID} | jq -r ". | .Requests | .progress_percent")
                    if [[ "${PROGRESS_PCT}" != "${PREVIOUS_PROGRESS_PCT}" ]]
                        then
                            log_progress "Current progress = ${PROGRESS_PCT}"
                            PREVIOUS_PROGRESS_PCT=${PROGRESS_PCT}
                        fi
                    sleep 3
                done
            echo
            log "COMPLETED"
    fi
}

prepare_templates() {
    log "prepare templates to upload"
    # Blueprint
    cp ${TEMPLATES_DIR}/${BLUEPRINT_TEMPLATE_FILENAME} ${TEMPLATES_DIR}/${BLUEPRINT_FILENAME}
    sed -i "s/<AMB_SERVER_HOSTNAME>/${AMB_HOST_INT}/g" ${TEMPLATES_DIR}/${BLUEPRINT_FILENAME}
    # Cluster template
    cp ${TEMPLATES_DIR}/${CLUSTER_TEMPLATE_FILENAME} ${TEMPLATES_DIR}/${CLUSTER_FILENAME}
    sed -i "s/<DEFAULT_ENV_PASSWORD>/${DEFAULT_ENV_PASSWORD}/g" ${TEMPLATES_DIR}/${CLUSTER_FILENAME}
    sed -i "s/<AMB_SERVER_HOSTNAME>/${AMB_HOST_INT}/g" ${TEMPLATES_DIR}/${CLUSTER_FILENAME}
    # Stack Repositories
    cp ${TEMPLATES_DIR}/${HDP_REPO_TEMPLATE_FILENAME} ${TEMPLATES_DIR}/${HDP_REPO_FILENAME}
    sed -i "s/<LOCAL_REPOSITORY_URL>/${LOCAL_REPOSITORY_URL}/g" ${TEMPLATES_DIR}/${HDP_REPO_FILENAME}
    cp ${TEMPLATES_DIR}/${HDPUTILS_REPO_TEMPLATE_FILENAME} ${TEMPLATES_DIR}/${HDPUTILS_REPO_FILENAME}
    sed -i "s/<LOCAL_REPOSITORY_URL>/${LOCAL_REPOSITORY_URL}/g" ${TEMPLATES_DIR}/${HDPUTILS_REPO_FILENAME}
}

upload_blueprint() {
    log "Register Blueprint ${BLUEPRINT_NAME} with Ambari"
    BLUEPRINT_NAME=$(cat ${TEMPLATES_DIR}/${BLUEPRINT_FILENAME} | jq -r '.Blueprints | .blueprint_name ')
    curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X POST http://${AMB_HOST}:8080/api/v1/blueprints/${BLUEPRINT_NAME} -d @${TEMPLATES_DIR}/${BLUEPRINT_FILENAME} || {
    log "FAILED"; exit 1
    }
}

# Setup Stack Repositories
setup_stack_repositories() {
    log "Setup Stack Repositories"
    curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X PUT http://${AMB_HOST}:8080/api/v1/stacks/HDP/versions/${HDP_STACK}/operating_systems/redhat6/repositories/HDP-${HDP_STACK} -d @${TEMPLATES_DIR}/${HDP_REPO_FILENAME} || {
    log "FAILED"; exit 1
    }

    curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X PUT http://${AMB_HOST}:8080/api/v1/stacks/HDP/versions/${HDP_STACK}/operating_systems/redhat6/repositories/HDP-UTILS-${HDP_UTILS_VERSION} -d @${TEMPLATES_DIR}/${HDPUTILS_REPO_FILENAME} || {
    log "FAILED"; exit 1
    }
}

# Create cluster from template
create_cluster() {
    log "Create cluster from template"
    JOB_ID=$(curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X POST http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME} -d @${TEMPLATES_DIR}/${CLUSTER_FILENAME} | jq -r ". | .Requests | .id")
    check_status ${JOB_ID}
}



# configure_hue() {
#     #
# }


kerberize() {

    # wget http://kerberos/krb5.conf -O /etc/krb5.conf

    log "Add the KERBEROS Service to cluster"
    curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X POST http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/services/KERBEROS
    log "Add the KERBEROS_CLIENT component to the KERBEROS service"
    curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X POST  http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/services/KERBEROS/components/KERBEROS_CLIENT


    log "Set KERBEROS service configurations"
    cp ${TEMPLATES_DIR}/${KERBEROS_CONFIG_TEMPLATE_FILENAME} ${TEMPLATES_DIR}/${KERBEROS_CONFIG_FILENAME}
    sed -i "s/<REALM>/${REALM}/g" ${TEMPLATES_DIR}/${KERBEROS_CONFIG_FILENAME}
    sed -i "s/<KDC_SERVER>/${KDC_SERVER}/g" ${TEMPLATES_DIR}/${KERBEROS_CONFIG_FILENAME}
    curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X PUT http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME} -d @${TEMPLATES_DIR}/${KERBEROS_CONFIG_FILENAME}

    log "Create the KERBEROS_CLIENT host components (once for each host, replace HOST_NAME)"
    curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X POST -d '{"host_components" : [{"HostRoles" : {"component_name":"KERBEROS_CLIENT"}}]}' http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/hosts?Hosts/host_name=${AMB_HOST_INT}

    log "Install the KERBEROS service and components"
    JOB_ID=$(curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X PUT -d '{"ServiceInfo": {"state" : "INSTALLED"}}' http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/services/KERBEROS | jq -r ". | .Requests | .id")
    check_status ${JOB_ID}

    log "Stop all services"
    JOB_ID=$(curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X PUT -d '{"ServiceInfo": {"state" : "INSTALLED"}}' http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/services | jq -r ". | .Requests | .id")
    check_status ${JOB_ID}

    log "Set kerberos descriptor"
    cp ${TEMPLATES_DIR}/${KERBEROS_DESCRIPTOR_TEMPLATE_FILENAME} ${TEMPLATES_DIR}/${KERBEROS_DESCRIPTOR_FILENAME}
    curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X POST http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/artifacts/kerberos_descriptor -d @${TEMPLATES_DIR}/${KERBEROS_DESCRIPTOR_FILENAME}

    log "Enable Kerberos"
    cp ${TEMPLATES_DIR}/${KERBEROS_CRED_TEMPLATE_FILENAME} ${TEMPLATES_DIR}/${KERBEROS_CRED_FILENAME}
    # sed -i "s/<KRB_ADMIN_PRINCIPAL>/${KRB_ADMIN_PRINCIPAL}/g" ${TEMPLATES_DIR}/${KERBEROS_CRED_FILENAME}
    # sed -i "s/<KRB_ADMIN_PRINCIPAL_PASSWORD>/${KRB_ADMIN_PRINCIPAL_PASSWORD}/g" ${TEMPLATES_DIR}/${KERBEROS_CRED_FILENAME}
    JOB_ID=$(curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X PUT http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME} -d @${TEMPLATES_DIR}/${KERBEROS_CRED_FILENAME} | jq -r ". | .Requests | .id")
    check_status ${JOB_ID}

    log "Start all services"
    JOB_ID=$(curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X PUT -d '{"ServiceInfo": {"state" : "STARTED"}}' http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/services | jq -r ". | .Requests | .id")
    check_status ${JOB_ID}
}

start_all_services() {
    JOB_ID=$(curl -sS -H "X-Requested-By: ambari" -u ${AMB_ADMIN}:${AMB_ADMIN_PASSWORD} -X PUT -d '{"ServiceInfo": {"state" : "STARTED"}}' http://${AMB_HOST}:8080/api/v1/clusters/${HDP_CLUSTER_NAME}/services | jq -r ". | .Requests | .id")
    check_status ${JOB_ID}
}

usage() {

    echo -e "Usage: $0 [OPTION]\n"
    echo "Available options:"
    for option in $(declare -F | cut -d " " -f 3 | sort)
    do
        echo -e "\t${option}"
    done
    echo
    echo "Set cluster parameter:"
    echo -e "HDP_CLUSTER_NAME=<name> AMB_HOST=<fqdn> AMB_ADMIN=<login> AMB_ADMIN_PASSWORD=<password> LOCAL_REPOSITORY_URL=<URL> HDP_STACK=<2.2> DEFAULT_ENV_PASSWORD=<password> HDP_UTILS_VERSION=<1.1.0.20> $0"
    echo

}

deploy_all() {
    prepare_templates
    upload_blueprint
    [[ "${USE_LOCAL_REPOSITORIES}" == "true" ]] && setup_stack_repositories
    create_cluster
    if [[ "${KERBERIZED}" == "true" ]]
        then
            kerberize
    fi
}

# Check depended variables
for i in HDP_CLUSTER_NAME AMB_HOST AMB_ADMIN AMB_ADMIN_PASSWORD LOCAL_REPOSITORY_URL HDP_STACK HDP_UTILS_VERSION DEFAULT_ENV_PASSWORD
    do
        [[ -z ${!i} ]] && {
            log "FAIL: ${i} is not set"
            usage
            exit 1
        }
    done


if [[ "${KERBERIZED}" == "true" ]]
        then
            for i in REALM KDC_SERVER
                do
                    [[ -z ${!i} ]] && {
                        log "FAIL: ${i} is not set"
                        usage
                        exit 1
                    }
                done
fi


if [[ -z $@ ]]
    then
        usage
        exit 1
fi

$@

