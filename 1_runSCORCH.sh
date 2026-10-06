#!/bin/bash

set -e

# ============================================================
# SCORCH2: Feature extraction, normalization, and rescoring
# ============================================================


# ------------------------------------------------------------
# SCORCH2 locations
# ------------------------------------------------------------

SCORCH2_LOC="/stor/system/opt/scorch2/SCORCH2-main"

MODELS="/stor/scratch/FRI_CH204_Spring2018/scorch2_evaluation_data"

# ------------------------------------------------------------
# Project settings
# ------------------------------------------------------------

DATA_DIR="$HOME/VDS/SCORCH"

PDB_ID="[ID]"

PROTEIN_INPUT_DIR="$DATA_DIR/pdbqt_receptor"
LIGAND_INPUT_DIR="$DATA_DIR/pdbqt_ligands"

FEATURE_DIR="$DATA_DIR/features"
NORMALIZED_DIR="$DATA_DIR/normalized_features"
RESULTS_DIR="$DATA_DIR/results"

# Final files
FEATURE_FILE="$FEATURE_DIR/${PDB_ID}_protein_features.csv"
RESULT_FILE="$RESULTS_DIR/${PDB_ID}_scorch2_results_agg.csv"

# ------------------------------------------------------------
# Create output directories
# ------------------------------------------------------------

mkdir -p "$FEATURE_DIR"
mkdir -p "$NORMALIZED_DIR"
mkdir -p "$RESULTS_DIR"

echo "======================================"
echo "SCORCH2 Rescoring Workflow"
echo "======================================"

echo ""
echo "PDB ID:       $PDB_ID"
echo "Protein:      $PROTEIN_INPUT_DIR"
echo "Ligands:      $LIGAND_INPUT_DIR"
echo "Features:     $FEATURE_DIR"
echo "Results:      $RESULTS_DIR"

# ------------------------------------------------------------
# Step 1: Feature extraction
# ------------------------------------------------------------

echo ""
echo "======================================"
echo "Step 1: Feature extraction"
echo "======================================"

python "$SCORCH2_LOC/utils/scorch2_feature_extraction.py" \
    --protein-dir "$PROTEIN_INPUT_DIR" \
    --ligand-dir "$LIGAND_INPUT_DIR" \
    --output-dir "$FEATURE_DIR"

if [ ! -f "$FEATURE_FILE" ]; then
    echo ""
    echo "ERROR: Feature file was not created:"
    echo "$FEATURE_FILE"
    exit 1
fi

echo ""
echo "Feature extraction complete:"
echo "$FEATURE_FILE"

# ------------------------------------------------------------
# Step 2: Normalize/scaling
# ------------------------------------------------------------

echo ""
echo "======================================"
echo "Step 2: Feature scaling"
echo "======================================"

python "$SCORCH2_LOC/evaluation/process_data.py" scaling \
    --feature_dir "$FEATURE_DIR" \
    --output_path "$NORMALIZED_DIR" \
    --pb_scaler_path "$MODELS/sc2_pb_scaler" \
    --ps_scaler_path "$MODELS/sc2_ps_scaler"

echo ""
echo "Feature scaling complete."

# ------------------------------------------------------------
# Step 3: SCORCH2 rescoring
# ------------------------------------------------------------

echo ""
echo "======================================"
echo "Step 3: SCORCH2 rescoring"
echo "======================================"

python "$SCORCH2_LOC/scorch2_rescoring.py" \
    --sc2_ps_model "$MODELS/sc2_ps.xgb" \
    --sc2_pb_model "$MODELS/sc2_pb.xgb" \
    --ps_scaler "$MODELS/sc2_ps_scaler" \
    --pb_scaler "$MODELS/sc2_pb_scaler" \
    --features "$FEATURE_FILE" \
    --output "$RESULT_FILE" \
    --aggregate

# ------------------------------------------------------------
# Verify final result
# ------------------------------------------------------------

if [ ! -f "$RESULT_FILE" ]; then
    echo ""
    echo "ERROR: SCORCH2 result file was not created."
    exit 1
fi

echo ""
echo "======================================"
echo "SCORCH2 complete"
echo "======================================"

echo ""
echo "Final aggregated results:"
echo "$RESULT_FILE"

echo ""
echo "Done."
