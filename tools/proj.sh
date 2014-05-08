#!/bin/sh

# Projectivise dependency data using the MaltParser.
#
# Example:
#
#   for F in `ls */{train,dtrain}.conll`; do B=`echo "${F}" \
#       | sed -e 's|\.conll$||'`; cat "${F}" \
#       | ./proj.sh > "${B}_proj.conll"; done;
#
# Author:   Pontus Stenetorp    <pontus stenetorp se>
# Version:  2013-01-04

SCRIPT_DIR=`dirname "${0}"`
MALT_DIR="${SCRIPT_DIR}/../wrk/maltparser"
MALT_JAR="${MALT_DIR}/maltparser.jar"

# Malt configuration file, for some absurd reason it needs to be in the
#   current working directory, so create it there. It also creates a directory
#   with a similar name! Depending on the `-m` argument.
MCO=`mktemp tmp_XXXXXXXXXX.mco`
MCO_DIR=`echo "${MCO}" | sed -e 's|\.mco$||g'`
trap "rm -r -f ${MCO} ${MCO_DIR}" INT TERM EXIT

# Make the conversion, Malt is noisy, so redirect stderr.
java -jar "${MALT_JAR}" -c "${MCO}" -m proj -pp baseline -i /dev/stdin \
    -o /dev/stdout 2> /dev/null
