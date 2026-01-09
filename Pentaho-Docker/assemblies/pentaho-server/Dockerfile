# This file is intended to be modified by the DockMaker.bat/sh command line
# Define the installation path as a global (before the FROM clauses)
ARG INSTALLATION_PATH=/opt/pentaho 
ARG PENTAHO_VERSION
ARG PENTAHO_SERVER_PATH=${INSTALLATION_PATH}/pentaho-server

# Single base image for offline deployment - includes OpenJDK 21
ARG BASE_IMAGE=eclipse-temurin:21-jre
ARG UNPACK_BUILD_IMAGE=${BASE_IMAGE}
ARG PACK_BUILD_IMAGE=${BASE_IMAGE}

FROM ${UNPACK_BUILD_IMAGE} AS install_unpack

LABEL maintainer="Hitachi Vantara"
LABEL version="11.x"
LABEL description="Dockerfile for Pentaho Server"

WORKDIR /opt/pentaho-installer/

#Arguments definition
ARG INSTALLATION_PATH
ARG PENTAHO_SERVER_PATH
ARG INSTALLER_PATH=/opt/pentaho-installer
## Arguments for regular Pentaho Server install
ARG PENTAHO_INSTALLER_NAME=pentaho-server-ee
ARG PENTAHO_VERSION=11.0.0.0-237
ARG IS_DEMO=0

ARG FILE_SOFTWARE=${PENTAHO_INSTALLER_NAME}-${PENTAHO_VERSION}.zip
## Arguments related to Pentaho Server plugins
ARG FILE_PAZ=paz-plugin-ee-${PENTAHO_VERSION}.zip
ARG FILE_PIR=pir-plugin-ee-${PENTAHO_VERSION}.zip
ARG FILE_PDD=pdd-plugin-ee-${PENTAHO_VERSION}.zip

#Copy from local predownloaded folder al the artifacts required for Pentaho installation
COPY ./stagedArtifacts/* ${INSTALLER_PATH}/

RUN apt-get update && \
    apt-get install -y unzip && \
    rm -rf /var/lib/apt/lists/*

##########################################
# Here comes the GA Install part
##########################################
#
# First, It validates if main software package (version release) is available or stop the process asking for file if not there
RUN if [ ! -f "${INSTALLER_PATH}/${FILE_SOFTWARE}" ]; \
        then \
        echo "File ${FILE_SOFTWARE} Not Found in predownloaded folder, please download required artifact and copy to predownloaded folder"; exit 2; \
    fi;

# Additional unpack logic placeholder - do not remove or change
# Where is the Install of extra packs for unpack? do we have a large image for build and same to run?

# UNZIP and INSTALL the Pentaho server
RUN mkdir -p ${INSTALLATION_PATH}; \
    unzip ${FILE_SOFTWARE} -d ${INSTALLATION_PATH};

# Remove promptUser.sh
RUN rm -f ${PENTAHO_SERVER_PATH}/promptuser.sh || true;

# UNZIP and INSTALL plugins
RUN if [ -f "${FILE_PAZ}" ]; \
    then \
      unzip -o ${FILE_PAZ} -d ${PENTAHO_SERVER_PATH}/pentaho-solutions/system; \
    fi;

RUN if [ -f "${FILE_PIR}" ]; \
    then \
      unzip -o ${FILE_PIR} -d ${PENTAHO_SERVER_PATH}/pentaho-solutions/system; \
    fi;

RUN if [ -f "${FILE_PDD}" ]; \
    then \
      unzip -o ${FILE_PDD} -d ${PENTAHO_SERVER_PATH}/pentaho-solutions/system; \
    fi;

# Remove default-content
RUN if [ "${IS_DEMO}" -eq "0" ]; \
    then \
      rm -rf ${PENTAHO_SERVER_PATH}/pentaho-solutions/system/default-content/*; \
    fi;

########################################################################################################################
#
# Since this image is for the GA release, no service pack in this build.
FROM ${PACK_BUILD_IMAGE} AS pack

#Arguments
ARG INSTALLATION_PATH
ARG PENTAHO_VERSION
ARG PENTAHO_SERVER_PATH=${INSTALLATION_PATH}/pentaho-server

# Additional pack logic placeholder - do not remove or change

# Create unprivileged user
ENV PENTAHO_UID=5000
ENV PENTAHO_USER=pentaho
ENV PENTAHO_HOME=/home/pentaho
# Ensure PENTAHO_SERVER_PATH is set correctly
ENV PENTAHO_SERVER_PATH=${PENTAHO_SERVER_PATH}
ENV PATH="${PENTAHO_SERVER_PATH}:${PATH}"
ENV PENTAHO_VERSION=${PENTAHO_VERSION}
ENV INSTALLATION_PATH=${INSTALLATION_PATH}


# Create user for non-root account
RUN groupadd --gid ${PENTAHO_UID} ${PENTAHO_USER} \
    && useradd --home-dir ${PENTAHO_HOME} --create-home --uid ${PENTAHO_UID} \
    --gid ${PENTAHO_UID} --shell /bin/bash --skel /dev/null ${PENTAHO_USER}
# RUN echo 'pentaho ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Install pending updates
RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean

# Java OpenJDK 21 is pre-installed in eclipse-temurin:21-jre base image

#Default to Windows host, please override for other cases
#ENV DISPLAY=host.docker.internal:0

#This Setting is to skipe WEB TOOLKIT GTK Check. Since the use of this mack normally does no use GUI.
# If you want GUI, then istall libwebkitgtk-1.0-0 as the line commented above
ENV SKIP_WEBKITGTK_CHECK=1

# Use installed software from installation base and assign non-elevated-privileges user in destination path
COPY --from=install_unpack --chown=${PENTAHO_USER}:${PENTAHO_USER} ${INSTALLATION_PATH}/ ${INSTALLATION_PATH}/

#COPY --chown=${PENTAHO_USER}:${PENTAHO_USER} ./entrypoint/ /
#Copy the entrypoint script to the root folder
COPY ./entrypoint/ /
RUN chmod +x /docker-entrypoint.sh

#Use pentaho-server installation dir as WORKDIR
WORKDIR ${PENTAHO_SERVER_PATH}

#Setup JVM level parameters/variables
ENV PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 "
#Expose 8080 to use with pentaho server
EXPOSE 8080
EXPOSE 8443

#Use pentaho user
USER ${PENTAHO_USER}

ENTRYPOINT ["/docker-entrypoint.sh"]

# Run Tomcat in foreground mode to keep container alive
CMD ["./tomcat/bin/catalina.sh", "run"]
