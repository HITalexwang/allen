# Makefile for Allén.
#
# Author:	Pontus Stenetorp	<pontus stenetorp se>
# Version:	2014-05-06

WRK=wrk
MALT_VER=1.8
MALT_URL=http://maltparser.org/dist/maltparser-${MALT_VER}.tar.gz
FETCH_CMD=wget
JULIA_CMD=julia

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
	for f in `ls test/sanity/*.jl`; \
	do \
		${JULIA_CMD} $${f}; \
	done;

.PHONY: coverage
coverage: JULIA_CMD+=--code-coverage
coverage: sanity

.PHONY: perf
perf: sanity
	for f in `ls test/perf/*.jl`; \
	do \
		${JULIA_CMD} $${f}; \
	done;

${WRK}/profile.txt: ${WRK} ${SRC} sanity
	${JULIA_CMD} test/profile.jl

.PHONY: profile
profile: ${WRK}/profile.txt

.PHONY: clean
clean:
	rm -r -f "${WRK}"
	find src test -name '*.cov' | xargs -r rm
