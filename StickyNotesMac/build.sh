#!/bin/bash
swiftc -o StickyNotesApp \
  DesignSystem.swift \
  StickyNotesAppMain.swift \
  Models/*.swift \
  Views/*.swift \
  ViewModels/*.swift \
  Services/*.swift \
  Documents/*.swift \
  -parse-as-library \
  -framework SwiftUI \
  -framework AppKit \
  -framework Foundation \
  -framework Network \
  -lsqlite3 && \
  killall "Sticky Notes" 2>/dev/null; \
  ./StickyNotesApp &
