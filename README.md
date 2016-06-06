# Single hdp node docker

## Info
This docker is packaged single node hdp cluster with services autodeployment. Also it is possible to make automatic services kerberezation.

## Used version

HDP 2.2.8

Ambari 2.1

## How to configure

You can change hdp docker behavior be editing docker-compose.yml file.

## How to use

### Use make

```
Change current directory to directory where docker-compose.yml located.

make build            # build image from Dockerfile

make pull             # download image from intropro docker registry

make run              # run container from image that is specified in docker-compose.yml file

make logs             # show container logs, check deployment status

make status           # check container status

make attach           # attach to container (it makes docker exec -it <container> bash)

make stop_and_remove  # stop and remove container
```
or 

### Use docker-compose

```
docker build -t single-node-hdp-env:2.2.8.0 . # build image

docker-compose up -d                # run container from image above in daemon mod

docker-compose logs                 # show container logs, check deployment status

docker-compose stop                 # stop container

docker-compose rm                   # remove container

docker-compose status               # check container status
```


## Services deployment

Used Ambari blueprint
