#!/bin/bash

# This script is designed to be called by the quality control task of the
# upgrade building recipe
# It should be run in the path where the upgrade files are available (${B} usually)

NRCHECKS=0
for file in *.version ; do
    NRCHECKS=$((NRCHECKS+1))
    # shellcheck disable=SC2010,SC2086
    for checksum in $(ls ${file%.version}.* | grep -v "\.version") ; do
        SHASUM="$(sha256sum "${checksum}" | cut -d' ' -f1)"
            if grep -q "^${SHASUM}\ " "${file}" ; then
                echo "$checksum OK"
            else
                echo "$checksum version checksum ERROR" >&2
                echo "Some rare situations might require you to try running -c cleansstate for this task and retry once" >&2
                exit 2
            fi
    done
done
if [ $NRCHECKS -eq 0 ] ; then
    echo "ERROR: No file checked" >&2
    exit 2
fi
