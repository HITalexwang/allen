# Makefile for Allén.
#
# Author:	Pontus Stenetorp	<pontus stenetorp se>
# Version:	2014-05-06

BUILD=build
MALT_VER=1.8
MALT_URL=http://maltparser.org/dist/maltparser-${MALT_VER}.tar.gz
FETCH_CMD=wget

${BUILD}:
	mkdir ${BUILD}

.DEFAULT_GOAL:=${BUILD}/maltparser
${BUILD}/maltparser: ${BUILD}
	${FETCH_CMD} -P build "${MALT_URL}"
	tar -x -z -f "${@}-${MALT_VER}.tar.gz" -C build
	cd build && ln -s -f "maltparser-${MALT_VER}" maltparser
	cd "${@}" && ln -s -f "maltparser-${MALT_VER}.jar" maltparser.jar

.PHONY: clean
clean:
	rm -r -f ${BUILD}
