#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "Usage: create-tar-gz.sh -o <TAR FILE NAME> -c <CLOUD PROVIDER> -p <PROJECT NAME> -i <IMAGE NAME> -f <COMMA DELIMITED FILES TO INCLUDE>"
    exit 1
fi

while getopts o:c:p:i:f: flag
do
    case "${flag}" in
        o) TAR_FILE_NAME=${OPTARG};;
        c) CLOUD_PROVIDER=${OPTARG};;
        p) PROJECT_NAME=${OPTARG};;
        i) IMAGE_NAME=${OPTARG};;
        f) INCLUDE_FILES=${OPTARG};;
    esac
done

# Extract image name
IFS='/' read -ra IMAGE_PARTS <<< "$IMAGE_NAME"
SIMPLE_IMAGE_NAME=${IMAGE_PARTS[${#IMAGE_PARTS[@]} - 1]}
SIMPLE_IMAGE_NAME=`echo "$SIMPLE_IMAGE_NAME" | tr : -`

# Saving image to tar file
echo "mkdir ./$CLOUD_PROVIDER/$PROJECT_NAME/image"
mkdir ./$CLOUD_PROVIDER/$PROJECT_NAME/image
echo "docker save $IMAGE_NAME | gzip > ./$CLOUD_PROVIDER/$PROJECT_NAME/image/image-$SIMPLE_IMAGE_NAME.tar.gz"
docker save $IMAGE_NAME | gzip > ./$CLOUD_PROVIDER/$PROJECT_NAME/image/image-$SIMPLE_IMAGE_NAME.tar.gz

if [ $PROJECT_NAME == "pentaho-server" ]
then
  if [ $CLOUD_PROVIDER == "azure" ]
  then
    cp ./assembly-tools/pentaho-server-yaml-tool/* ./$CLOUD_PROVIDER/$PROJECT_NAME/yaml/AKS/
   else
    cp ./assembly-tools/pentaho-server-yaml-tool/* ./$CLOUD_PROVIDER/$PROJECT_NAME/yaml/
  fi
fi

# Add ../ to file names
IFS=',' read -ra FILES <<< "$INCLUDE_FILES"
FILES_FOR_TAR=""
CURRENT_PATH=$(pwd)
for i in "${FILES[@]}"; do
  echo "Checking file for inclusion: $i"
  if [ -f $i ] || [ -d "$CURRENT_PATH/$CLOUD_PROVIDER/$PROJECT_NAME/$i" ]
  then
    echo "Marking file for inclusion: $i"
    FILES_FOR_TAR="$FILES_FOR_TAR ../$i"
  fi
done

# Create tar file
echo "mkdir ./$CLOUD_PROVIDER/$PROJECT_NAME/distribution"
mkdir ./$CLOUD_PROVIDER/$PROJECT_NAME/distribution
echo "cd ./$CLOUD_PROVIDER/$PROJECT_NAME/distribution"
cd ./$CLOUD_PROVIDER/$PROJECT_NAME/distribution
echo "tar -czvf $SIMPLE_IMAGE_NAME.tar.gz $FILES_FOR_TAR"
tar -czvf $SIMPLE_IMAGE_NAME.tar.gz $FILES_FOR_TAR
