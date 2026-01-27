#!/bin/bash
# =============================================================================
# Pentaho Server Docker Start Script
# =============================================================================
#
# This script is a Docker-compatible version of start-pentaho.sh that runs
# Tomcat in the foreground instead of the background.
#
# The original start-pentaho.sh uses 'startup.sh' which runs Tomcat as a
# daemon and exits, causing Docker containers to terminate. This script
# uses 'catalina.sh run' to keep Tomcat in the foreground.
#
# =============================================================================

DIR_REL=`dirname $0`
cd $DIR_REL
DIR=`pwd`

# Source environment configuration
. "$DIR/set-pentaho-env.sh"
setPentahoEnv "$DIR/jre"

# **************************************************
# ** Platform specific libraries ...              **
# **************************************************

LIBPATH="NONE"
CURRENTDIR=$DIR
if [ -z ${PENTAHO_LIB_DIR} ]; then
  PENTAHO_LIB_DIR="$DIR/tomcat/webapps/pentaho/WEB-INF/lib"
fi

# Determine platform and set library path
case `uname -s` in
	Linux)
	ARCH=`uname -m`
		case $ARCH in
			i[3-6]86)
				LIBPATH=$CURRENTDIR/pentaho-solutions/native-lib/linux/x86/
				;;
			x86_64)
				LIBPATH=$CURRENTDIR/pentaho-solutions/native-lib/linux/x86_64/
				;;
			aarch64)
				LIBPATH=$CURRENTDIR/pentaho-solutions/native-lib/linux/aarch64/
				;;
			*)
				echo "Warning: Unsupported Linux architecture [$ARCH], native libraries may not be available"
				;;
		esac
		;;
	Darwin)
	ARCH=`uname -m`
		case $ARCH in
			x86_64)
				LIBPATH=$CURRENTDIR/pentaho-solutions/native-lib/osx64/
				;;
			arm64)
				LIBPATH=$CURRENTDIR/pentaho-solutions/native-lib/osx64_aarch/
				;;
			*)
				echo "Warning: Unsupported Mac architecture [$ARCH], native libraries may not be available"
				;;
		esac
		;;
	*)
		echo "Warning: Unsupported OS [$(uname -s)], native libraries may not be available"
		;;
esac

# Copy native library JARs if available
if [ "$LIBPATH" != "NONE" ] && [ -d "$LIBPATH" ]; then
  # Use find to avoid errors if no .jar files exist
  if ls "$LIBPATH"*.jar >/dev/null 2>&1; then
    cp "$LIBPATH"*.jar "$PENTAHO_LIB_DIR/"
  else
    echo "Warning: No native library JARs found in $LIBPATH"
  fi
fi

### =========================================================== ###
## Set a variable for DI_HOME (to be used as a system property)  ##
## The plugin loading system for kettle needs this set to know   ##
## where to load the plugins from                                ##
### =========================================================== ###
DI_HOME="$DIR/pentaho-solutions/system/kettle"

# Change to Tomcat bin directory
cd "$DIR/tomcat/bin"

# Configure Catalina options (JVM settings)
CATALINA_OPTS="-Xms${PENTAHO_MIN_MEMORY:-2048m} -Xmx${PENTAHO_MAX_MEMORY:-6144m}"
CATALINA_OPTS="$CATALINA_OPTS -Djava.library.path=$LIBPATH"
CATALINA_OPTS="$CATALINA_OPTS -Dsun.rmi.dgc.client.gcInterval=3600000"
CATALINA_OPTS="$CATALINA_OPTS -Dsun.rmi.dgc.server.gcInterval=3600000"
CATALINA_OPTS="$CATALINA_OPTS -Dfile.encoding=utf8"
CATALINA_OPTS="$CATALINA_OPTS -Djava.locale.providers=COMPAT,SPI"
CATALINA_OPTS="$CATALINA_OPTS -DDI_HOME=\"$DI_HOME\""

# ORC compatibility with protobuf-java 3.25.6
CATALINA_OPTS="$CATALINA_OPTS -Dcom.google.protobuf.use_unsafe_pre22_gencode=true"
export CATALINA_OPTS

# License information path
if [ -n "$PENTAHO_LICENSE_INFORMATION_PATH" ]; then
     export CATALINA_OPTS="$CATALINA_OPTS -Dpentaho.license.information.file=$PENTAHO_LICENSE_INFORMATION_PATH"
fi

# Java 9+ options to remove illegal reflective access warnings
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/sun.net.www.protocol.jar=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/java.lang=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/java.io=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/java.lang.reflect=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/java.net=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/java.security=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/java.util=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/sun.net.www.protocol.file=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/sun.net.www.protocol.ftp=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/sun.net.www.protocol.http=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/sun.net.www.protocol.https=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/sun.reflect.misc=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.management/javax.management=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.management/javax.management.openmbean=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.naming/com.sun.jndi.ldap=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/java.math=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/sun.nio.ch=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.base/java.nio=ALL-UNNAMED"
JDK_JAVA_OPTIONS="$JDK_JAVA_OPTIONS --add-opens=java.security.jgss/sun.security.krb5=ALL-UNNAMED"
export JDK_JAVA_OPTIONS

# Set JAVA_HOME
JAVA_HOME=$_PENTAHO_JAVA_HOME
export JAVA_HOME

echo "Starting Tomcat in foreground mode..."
echo "CATALINA_OPTS=$CATALINA_OPTS"
echo "JAVA_HOME=$JAVA_HOME"

# Use 'catalina.sh run' instead of 'startup.sh' to keep Tomcat in foreground
# This is essential for Docker containers to stay alive
exec sh catalina.sh run
