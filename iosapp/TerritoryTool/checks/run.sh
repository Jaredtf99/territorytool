#!/bin/bash
# Verifica el contrato de decodificación de los DTO contra fixtures, compilando los
# archivos de producción reales. El proyecto no tiene target de tests todavía; cuando lo
# tenga, esto debería migrarse a XCTest tal cual.
set -e
cd "$(dirname "$0")"
SRC=../TerritoryTool
OUT=$(mktemp -d)
swiftc -swift-version 5 \
  -enable-upcoming-feature MemberImportVisibility \
  -default-isolation MainActor \
  -o "$OUT/check" \
  main.swift \
  polylabel.swift \
  "$SRC/Shared/Models/Territory.swift" \
  "$SRC/Shared/Models/Transaction.swift" \
  "$SRC/Core/Network/DTO/TerritoryRowDTO.swift" \
  "$SRC/Core/Network/SupabaseJSONDecoder.swift" \
  "$SRC/Shared/Models/TerritoryMapGeometry+Fingerprint.swift" \
  "$SRC/Features/Territories/Views/Map/TerritoryMapGeometryPreprocessor.swift"
"$OUT/check"
