# Makefile for Allén.
#
# Author:	Pontus Stenetorp	<pontus stenetorp se>
# Version:	2014-05-06

# TODO: Rename build to wrk

BUILD=build
MALT_VER=1.8
MALT_URL=http://maltparser.org/dist/maltparser-${MALT_VER}.tar.gz
FETCH_CMD=wget

${BUILD}:
	mkdir ${BUILD}

${BUILD}/maltparser: ${BUILD}
	${FETCH_CMD} -P build "${MALT_URL}"
	tar -x -z -f "${@}-${MALT_VER}.tar.gz" -C build
	cd build && ln -s -f "maltparser-${MALT_VER}" maltparser
	cd "${@}" && ln -s -f "maltparser-${MALT_VER}.jar" maltparser.jar

.DEFAULT_GOAL:=sanity
.PHONY: sanity
sanity:
	julia test/sanity/sanity.jl

.PHONY: clean
clean:
	rm -r -f ${BUILD}
