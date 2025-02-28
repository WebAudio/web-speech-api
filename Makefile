SHELL := /bin/bash

DST := $(patsubst %.bs,%.html,$(wildcard *.bs))
REMOTE := $(filter remote,$(MAKECMDGOALS))

all: $(DST)
	@ echo "All done"

%.html : %.bs node_modules/vnu-jar/build/dist/vnu.jar
ifndef REMOTE
	@ echo "Building $@"
	bikeshed --die-on=warning spec $< $@
	java -jar node_modules/vnu-jar/build/dist/vnu.jar --also-check-css $@
else
	@ echo "Building $@ remotely"
	@ (HTTP_STATUS=$$(curl https://api.csswg.org/bikeshed/ \
	                       --output $@ \
	                       --write-out "%{http_code}" \
	                       --header "Accept: text/plain, text/html" \
	                       -F die-on=warning \
	                       -F file=@$<) && \
	[[ "$$HTTP_STATUS" -eq "200" ]]) || ( \
		echo ""; cat $@; echo ""; \
		rm -f index.html; \
		exit 22 \
	);
endif

node_modules/vnu-jar/build/dist/vnu.jar:
	npm install vnu-jar

remote: all

