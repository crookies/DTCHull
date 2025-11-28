#!/bin/sh
# The 'set -e' command ensures that the script will exit immediately if any command fails (returns a non-zero exit status).
set -e
cd "${0%/*}" || exit
# REMOVED: . ${WM_PROJECT_DIR:?}/bin/tools/RunFunctions (Bypassing OpenFOAM's protective wrapper functions)

# --- READ PARALLEL PARAMETER ---
# Read NPROC from system/constant/parametersDict
NPROC=$(foamDictionary system/constant/parametersDict -entry NPROC -value)
echo "Starting Mesh Generation Workflow with $NPROC processors..."

# --- Housekeeping: Delete old log files and decomposed data ---
echo "Deleting old log files and parallel data..."
rm -f log.*
rm -rf processor*

# 1. Clean previous mesh data and ensure directories exist
echo "Cleaning old mesh data..."
rm -rf constant/polyMesh
rm -rf constant/triSurface/domain.stl
rm -rf constant/triSurface/plane.stl
# CLEANUP: Removed temporary flipped file (DTC-sim-half.stl) as it's no longer needed
rm -rf constant/triSurface/meshGeometry.stl

# NOTE: It is assumed that constant/triSurface/DTC-half.stl (the Y<=0 cut) is provided by the user.

# 2. Generate the Domain Box (Background Mesh)
echo "Generating background domain from blockMeshDict..."
blockMesh > log.blockMesh 2>&1 || { echo "ERROR: blockMesh failed. Check log.blockMesh. Exiting."; exit 1; }

# Convert the blockMesh domain to an STL surface for later combination
echo "Converting blockMesh domain to domain.stl surface..."
foamToSurface constant/triSurface/domain.stl > log.foamToSurface_domain 2>&1 || { echo "ERROR: foamToSurface failed for domain. Check log.foamToSurface_domain. Exiting."; exit 1; }

# 3. Combine Half-Hull and Domain into one file for cfMesh
echo "Combining Half-Hull and Domain into meshGeometry.stl..."
# Now uses the manually prepared DTC-half.stl directly.
cat constant/triSurface/domain.stl constant/triSurface/DTC-half.stl > constant/triSurface/meshGeometry.stl

# 5. Run cfMesh (cartesianMesh) 
echo "Running cartesianMesh (cfMesh)..."
cartesianMesh  > log.cartesianMesh 2>&1 || { echo "ERROR: cartesianMesh failed. Check log.cartesianMesh. Exiting."; exit 1; }

# 7. Check the reconstructed mesh quality
echo "Checking mesh quality..."
checkMesh > log.checkMesh 2>&1 || { echo "WARNING: checkMesh reported issues. Check log.checkMesh. Proceeding anyway."; }

# 8. Clean up processor directories
echo "Cleaning up processor directories..."
rm -rf processor*

# 9. Renumber mesh for parallel efficiency later
echo "Renumbering mesh..."
renumberMesh -overwrite > log.renumberMesh 2>&1 || { echo "ERROR: renumberMesh failed. Check log.renumberMesh. Exiting."; exit 1; }

echo "Meshing Complete. Review constant/polyMesh in ParaView."