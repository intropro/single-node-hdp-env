#
#	variables
#

SHELL := /bin/bash
IMAGE := `grep "    image" ./docker-compose.yml | sed 's/image: //g'`
PROJECT_NAME := HDP
#
#	actions
#

# Change HDP version
# Example make change_version_to HDP_VERSION=2.2.8.0
change_version_to:
	$ build-content/replace_hdp_version.sh $$HDP_VERSION

build:
	@ docker build -t $(IMAGE) .

push:
	@ docker push $(IMAGE)

pull:
	@ docker pull $(IMAGE)

run:
	@ docker-compose -p $(PROJECT_NAME) -f ./docker-compose.yml up -d

debug_run:
	@ docker run -it --rm --privileged=true --name $(PROJECT_NAME) $(IMAGE) bash

logs:
	@ docker-compose -p $(PROJECT_NAME) -f ./docker-compose.yml logs

status:
	@ docker-compose -p $(PROJECT_NAME) -f ./docker-compose.yml ps

stop_and_remove:
	@ docker-compose -p $(PROJECT_NAME) -f ./docker-compose.yml stop; docker-compose -p $(PROJECT_NAME) -f ./docker-compose.yml rm -f

attach:
	@ docker exec -it  `docker-compose -p $(PROJECT_NAME) -f ./docker-compose.yml ps -q` bash

none_images_remove:
	@ docker images | grep none | tr -s ' ' | cut -d ' ' -f 3 | xargs docker rmi
