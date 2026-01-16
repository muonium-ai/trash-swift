# Copyright (c) 2026 Senthil Nayagam

SWIFT_BUILD?=swift build
SWIFT_RUN?=swift run
PREFIX?=/usr/local
BIN_DIR?=$(PREFIX)/bin
BUILD_OUTPUT?=.build/release/trash

.PHONY: all build run install test clean

all: build

build:
	$(SWIFT_BUILD)

run:
	$(SWIFT_RUN) trash

install:
	$(SWIFT_BUILD) -c release
	install -d "$(BIN_DIR)"
	install "$(BUILD_OUTPUT)" "$(BIN_DIR)/trash"

test:
	swift test

clean:
	swift package clean
