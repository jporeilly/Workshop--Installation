#######################################################################################################
# The build process is done in 2 parts to make the final image as slim as possible                    #
# build image (install_unpack) copies and unpacks the software distribution packages                  #
# build image (pack) moves from install_unpack the files and defines workspace, entry-point and others #
#######################################################################################################

##################################################################################################
# Here we use a "build" image for packing to make the final image as small as possible           #
##################################################################################################
ARG INSTALLATION_PATH=/opt/pentaho
ARG PENTAHO_VERSION
ARG PENTAHO_PDI_PATH=${INSTALLATION_PATH}/data-integration
ARG UNPACK_BUILD_IMAGE=one.hitachivantara.com/docker/debian:trixie-slim
ARG PACK_BUILD_IMAGE=one.hitachivantara.com/docker/debian:trixie-slim

FROM ${UNPACK_BUILD_IMAGE} AS install_unpack

LABEL maintainer="Hitachi Vantara"
LABEL version="11.x"
LABEL description="Dockerfile for Pentaho Data Integration"

WORKDIR /opt/pentaho-installer/

#Arguments definition
ARG INSTALLATION_PATH
ARG PENTAHO_PDI_PATH
ARG INSTALLER_PATH=/opt/pentaho-installer
ARG PENTAHO_VERSION=11.0.0.0-xxx
ARG FILE_SOFTWARE=pdi-ee-client-${PENTAHO_VERSION}.zip
ARG FILE_HADOOP_ADDON=

#Copy from local predownloaded folder all the artifacts required for Pentaho installation
COPY ./stagedArtifacts/* ${INSTALLER_PATH}/

RUN apt-get update && \
    apt-get install -y unzip && \
    rm -rf /var/lib/apt/lists/*

##########################################
# Here comes the GA Install part
##########################################
#
# First, It validates if main software package (version release) is available or stop the process asking for file if not there
RUN echo "${INSTALLER_PATH}/$FILE_SOFTWARE"; if [ ! -f "${INSTALLER_PATH}/$FILE_SOFTWARE" ]; \
        then \
        echo "File ${FILE_SOFTWARE} Not Found in predownloaded folder, please download required artifact and copy to predownloaded folder"; exit 2; \
    fi;

# Additional unpack logic placeholder - do not remove or change
# Where is the Install of extra packs for unpack? do we have a large image for build and same to run?

# UNZIP and INSTALL the Pentaho Client
RUN mkdir -p ${INSTALLATION_PATH}; \
    unzip -o ${FILE_SOFTWARE} -d ${INSTALLATION_PATH};

# UNZIP and INSTALL hadoop add-on
RUN if [ -f "${FILE_HADOOP_ADDON}" ]; \
        then \
          unzip -o ${FILE_HADOOP_ADDON} -d ${INSTALLATION_PATH}; \
        fi;

# PDI-20601 Create logs folder to be usable by a writable mounted volume
RUN mkdir ${INSTALLATION_PATH}/data-integration/logs

##################################################################################################
# Here is where we create the final image                                                        #
##################################################################################################
FROM ${PACK_BUILD_IMAGE} AS pack

#Arguments
ARG INSTALLATION_PATH
ARG PENTAHO_VERSION
ARG PENTAHO_PDI_PATH

# Create unprivileged user
ENV PENTAHO_UID=5000
ENV PENTAHO_USER=pentaho
ENV PENTAHO_HOME=/home/pentaho
ENV PENTAHO_PDI_PATH=${PENTAHO_PDI_PATH}
ENV PATH="${PENTAHO_PDI_PATH}:${PATH}"
ENV PENTAHO_VERSION=${PENTAHO_VERSION}
ENV INSTALLATION_PATH=${INSTALLATION_PATH}
# Create user for non-root account
RUN groupadd --gid ${PENTAHO_UID} ${PENTAHO_USER} \
    && useradd --home-dir ${PENTAHO_HOME} --create-home --uid ${PENTAHO_UID} \
    --gid ${PENTAHO_UID} --shell /bin/bash --skel /dev/null ${PENTAHO_USER}

# Install pending updates
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean

# Install Java OpenJDK 21
RUN apt-get update && \
    apt-get install -y openjdk-21-jre-headless && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# RUN echo 'pentaho ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Additional pack logic placeholder - do not remove or change

#Default to Windows host, please override for other cases
#ENV DISPLAY=host.docker.internal:0

#This Setting is to skipe WEB TOOLKIT GTK Check. Since the use of this mack normally does no use GUI.
# If you want GUI, then istall libwebkitgtk-1.0-0 as the line commented above
ENV SKIP_WEBKITGTK_CHECK=1

# Use installed software from installation base and assign non-elevated-privileges user in destination path
COPY --from=install_unpack --chown=${PENTAHO_USER}:${PENTAHO_USER} ${INSTALLATION_PATH}/ ${INSTALLATION_PATH}/

#Assign permissions to pentaho on /opt/pentaho
RUN chown ${PENTAHO_USER}:${PENTAHO_USER} ${INSTALLATION_PATH}
#Copy the entrypoint script to the root folder
COPY ./entrypoint/ /

#Use data-integration installation dir as WORKDIR
WORKDIR ${PENTAHO_PDI_PATH}



#Setup JVM level parameters/variables
ENV PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 "


#Expose 8080 to use with carte
EXPOSE 8080
#Use pentaho user
USER ${PENTAHO_USER}

#Run the docker-entrypoint.sh to bring in override files
ENTRYPOINT ["/docker-entrypoint.sh"]
