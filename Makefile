# Makefile for claude-cage

CLAUDE_IMAGE ?= ghcr.io/gw0/claude-cage:main

SHELL := /bin/bash
.PHONY: build fmt

build:
	docker build --progress=plain -t $(CLAUDE_IMAGE) .

fmt:
	@errors=0; \
	\
	echo "Formatting *.sh scripts..."; \
	git ls-files -- '*.sh' \
	    | xargs -r shfmt -l -w -i 2 || ((errors++)); \
	git ls-files -- '*.sh' \
	    | xargs -r shellcheck || ((errors++)); \
	\
	echo "Formatting shell scripts without extension..."; \
	git ls-files \
	    | awk -F/ '$$NF !~ /\./' \
	    | xargs -r grep -lm1 "^#!/bin/\(ba\)\?sh" 2>/dev/null \
	    | xargs -r shfmt -l -w -i 2 || ((errors++)); \
	git ls-files \
	    | awk -F/ '$$NF !~ /\./' \
	    | xargs -r grep -lm1 "^#!/bin/\(ba\)\?sh" 2>/dev/null \
	    | xargs -r shellcheck || ((errors++)); \
	\
	echo "Formatting Dockerfile files..."; \
	git ls-files -- 'Dockerfile*' \
	    | xargs -r dockerfmt --write || ((errors++)); \
	\
	echo "Formatting YAML files..."; \
	git ls-files -- '*.yml' '*.yaml' \
	    | xargs -r yamlfmt || ((errors++)); \
	\
	echo "Formatting Markdown files..."; \
	git ls-files -- '*.md' \
	    | xargs -r markdownlint-cli2 --fix --no-globs >/dev/null || ((errors++)); \
	\
	echo "Done (errors: $${errors})"; \
	exit $${errors}
