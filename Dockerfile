FROM centos:centos6

# onbuild arg variables
ARG AMB_VERSION=2.1.2.1
ARG HDP_VERSION=2.2.8.0
ARG HDP_STACK=2.2
ARG HDP_UTILS_VERSION=1.1.0.20
ARG USE_LOCAL_REPOSITORIES=false
ARG LOCAL_REPOSITORY_URL=repo.local:8080
ARG KERBERIZED=false
# Persisted image variables
ENV HDP_CLUSTER_NAME=${HDP_CLUSTER_NAME:-Cluster1} \
    AMB_VERSION=${AMB_VERSION} \
    AMB_ADMIN=admin \
    AMB_ADMIN_PASSWORD=admin \
    HDP_VERSION=${HDP_VERSION} \
    HDP_UTILS_VERSION=${HDP_UTILS_VERSION} \
    HDP_STACK=${HDP_STACK} \
    USE_LOCAL_REPOSITORIES=${USE_LOCAL_REPOSITORIES} \
    KERBERIZED=${KERBERIZED} \
    LC_ALL="en_US.UTF-8" \
    TERM=xterm \
    TIMEZONE=GMT \
    TRACE=1 \
    DEFAULT_ENV_USER=bigdata \
    DEFAULT_ENV_PASSWORD=bigdata \
    DEFAULT_ROOT_PASSWORD=root \
    LOCAL_REPOSITORY_URL=${LOCAL_REPOSITORY_URL} \
    DEPLOY_HDP_SERVICES=true
    
# Build image part
COPY ./onbuild /onbuild

RUN /onbuild/scripts/base.sh all
RUN /onbuild/scripts/jdk.sh all
RUN /onbuild/scripts/ambari.sh all

# Deploy from running container part
ENV DEFAULT_USE_LOCAL_TEMPLATES=true
COPY ./onrun/deploy /deploy

CMD supervisord