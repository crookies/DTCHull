#!/bin/sh
cd ${0%/*} || exit 1    # Run from this directory

# Source tutorial run functions
. $WM_PROJECT_DIR/bin/tools/RunFunctions

# Get application name
application=$(getApplication)

# -----------------------------------------------------------------------------
# 1. Background Mesh Generation
# -----------------------------------------------------------------------------
echo "Running blockMesh..."
runApplication blockMesh || { echo "Error: blockMesh failed"; exit 1; }


# -----------------------------------------------------------------------------
# 2. Surface Feature Extraction
# -----------------------------------------------------------------------------
echo "Running surfaceFeatureExtract..."
runApplication surfaceFeatureExtract || { echo "Error: surfaceFeatureExtract failed"; exit 1; }

# -----------------------------------------------------------------------------
# 3. Background Mesh Refinement Loop
#    Iterate through topoSetDict.1 to .6 to refine the free surface zone
# -----------------------------------------------------------------------------
echo "Running refinement loop (topoSet + refineMesh)..."

for i in 1 2 3 4 5 6
do
    echo "Refinement step $i..."
    runApplication -s "$i" topoSet -dict system/topoSetDict.${i} || { echo "Error: topoSet step $i failed"; exit 1; }
    runApplication -s "$i" refineMesh -dict system/refineMeshDict -overwrite || { echo "Error: refineMesh step $i failed"; exit 1; }
done

 
# -----------------------------------------------------------------------------
# 4. SnappyHexMesh (Parallel Execution)
# -----------------------------------------------------------------------------
echo "Decomposing for snappyHexMesh..."
runApplication decomposePar || { echo "Error: decomposePar failed"; exit 1; }

echo "Running snappyHexMesh in parallel..."
runParallel snappyHexMesh -overwrite || { echo "Error: snappyHexMesh failed"; exit 1; }

echo "Reconstructing mesh..."
runApplication reconstructParMesh -constant || { echo "Error: reconstructParMesh failed"; exit 1; }

# -----------------------------------------------------------------------------
# 5. Cleanup
#    (Optional) Remove the processor directories to save space/clean up
# -----------------------------------------------------------------------------
# rm -rf processor*

echo "Mesh generation complete."