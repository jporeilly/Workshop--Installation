#!/bin/bash
 
# Here we will override all the files from the "/docker-entrypoint-init" into the pentaho base folder.
# This allows users to change configuration files before server starts

if [ -z "$LICENSE_URL" ]; then
	echo '$LICENSE_URL is not set'
fi

echo "The version is $PENTAHO_VERSION"
for dir in $(find /docker-entrypoint-init/ -mindepth 1 -maxdepth 1 -type d | sort); do
	if [ -f "$dir/.ignore" ]; then
		echo "Skipping $dir due to .ignore file"
		continue
	fi
	echo found $(find $dir -type f -print | wc -l) files to be copied from $dir
	cp -a "$dir/." "$PENTAHO_PDI_PATH/"
done

if [ -f "$PENTAHO_SERVER_PATH/extra-entrypoint.sh" ]; then
	echo "Found extra-entrypoint.sh, executing it."
	. "$PENTAHO_SERVER_PATH/extra-entrypoint.sh"
fi

if [ ! -f ~/.pentaho/.elmLicInfo.plt ]; then
	echo "Installing License with url $LICENSE_URL"
	$INSTALLATION_PATH/license-installer/install_license.sh $LICENSE_URL;
fi

exec "$@"
