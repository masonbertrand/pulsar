#!/bin/zsh
# Builds and runs the logic tests (tests/). Only Foundation code goes in here: the files listed in LOGICA
# must not need AppKit or SwiftUI. Add a new pure logic file to LOGICA and its tests to tests/.
set -e
cd "$(dirname "$0")"
LOGICA=(Core/Riunione.swift Moduli/Isola/isola-logica.swift
  Moduli/Widget/calendario-logica.swift Moduli/Lite/aggiornamenti-logica.swift
  Moduli/Widget/stats-logica.swift Moduli/Isola/claude-logica.swift
  Moduli/Isola/schede-logica.swift Moduli/Isola/strumenti-schede-logica.swift
  Moduli/Widget/tessere-logica.swift)
mkdir -p build
swiftc -D DA_SORGENTE $LOGICA tests/*.swift -o build/pulsar-tests
./build/pulsar-tests
