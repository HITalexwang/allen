# Makefile for Allén.
#
# Author:	Pontus Stenetorp	<pontus stenetorp se>
# Version:	2014-05-06

WRK=wrk
MALT_VER=1.8
MALT_URL=http://maltparser.org/dist/maltparser-${MALT_VER}.tar.gz
FETCH_CMD=wget

SRC=${shell find src test -name '*.jl'}

${WRK}:
	mkdir "${WRK}"

${WRK}/maltparser: ${WRK}
	${FETCH_CMD} -P "${WRK}" "${MALT_URL}"
	tar -x -z -f "${@}-${MALT_VER}.tar.gz" -C "${WRK}"
	cd "${WRK}" && ln -s -f "maltparser-${MALT_VER}" maltparser
	cd "${@}" && ln -s -f "maltparser-${MALT_VER}.jar" maltparser.jar

.DEFAULT_GOAL:=sanity
.PHONY: sanity
sanity:
	julia test/sanity/sanity.jl

.PHONY: coverage
coverage:
	julia --code-coverage test/sanity/sanity.jl

# TODO: Depend on sanity?
.PHONY: perf
perf:
	julia test/perf/perf.jl

# TODO: Depend on sanity?
${WRK}/profile.txt: ${WRK} ${SRC}
	julia test/profile.jl

.PHONY: profile
profile: ${WRK}/profile.txt

.PHONY: clean
clean:
	rm -r -f "${WRK}"
	find src -name '*.cov' | xargs -r rm
