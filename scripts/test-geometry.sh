#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build
swiftc Sources/PetGeometry/Geometry.swift Sources/PetGeometry/NotificationLayout.swift Tests/PetGeometryTests/GeometryTests.swift -o .build/geometry-checks
.build/geometry-checks
