#!/bin/bash
# SET YOUR ENVIRONMENT VARIABLES
# USING PERL FOR MAC AND LINUX COMPATIBILITY FOR SED ALTERNATIVE
# THESE ARE THE SAMPLE CONFIGURATIONS VALUES! DO NOT USE OUTSIDE OF TESTING!
DOCKER_NAME='stepca-pdns'
STEPCA_SECRET=$(xxd -l32 -ps /dev/urandom | xxd -r -ps | base64 | tr -d = | tr + - | tr / _)
STEPCA_ORGANIZATION='Example Org'
STEPCA_PROVISIONER='admin@example.com'
STEPCA_CA_DOMAIN='example.com'
PDNS_WEBSERVER_PASSWORD=$(xxd -l8 -ps /dev/urandom)
PDNS_API_KEY=$(xxd -l32 -ps /dev/urandom | xxd -r -ps | base64 | tr -d = | tr + - | tr / _)

DOCKERBUILD(){
    # BUILD Docker Image
    export DOCKER_SCAN_SUGGEST=false
    docker build -t local/$DOCKER_NAME .
}

DOCKERSTART(){
    # Start Docker Container in Detach mode
    docker run --name $DOCKER_NAME -d  -p 0.0.0.0:8081:8081 -p 0.0.0.0:8443:8443 local/$DOCKER_NAME
}

echo "Starting Step-CA with PowerDNS Docker Build!"
while true; do
    read -p "Would you like to run the example configurations? [Yes/no]" ANSWER
    case ${ANSWER:-Yes} in
        [Yy]es) echo "$ANSWER"
            perl -i -pe "s/ContainerLabel/$DOCKER_NAME/g" ./Dockerfile
            perl -i -pe "s/SuperSecret/$STEPCA_SECRET/g" ./Dockerfile
            perl -i -pe "s/Example Org/$STEPCA_ORGANIZATION/g" ./Dockerfile
            perl -i -pe "s/provisioneremail/$STEPCA_PROVISIONER/g" ./Dockerfile
            perl -i -pe "s/domain.tld/$STEPCA_CA_DOMAIN/g" ./Dockerfile
            perl -i -pe "s/WebAdminPWD/$PDNS_WEBSERVER_PASSWORD/g" ./Dockerfile
            perl -i -pe "s/ApiKEYpdns/$PDNS_API_KEY/g" ./Dockerfile
            DOCKERBUILD
            DOCKERSTART
            exit 1;;
        [Nn]o ) echo $ANSWER
            

            exit 1;;
        * ) echo "Please answer yes or no.";;
    esac
done



