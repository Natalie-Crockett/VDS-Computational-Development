#!/bin/bash
set -e

SCORCH2_LOC="/stor/system/opt/scorch2/SCORCH2-main"
ADFR_LOC="/stor/system/opt/ADFR/bin"

# =========================
# CHANGE THESE FOR EACH SET
# =========================

PDB_ID="7U9K"

DATA_DIR="$HOME/VDS/SCORCH"

PROTEIN_INPUT="$DATA_DIR/SaDalaDala_protein.mol2"
LIGAND_INPUT_SDF="$DATA_DIR/SaDalaDalavsHF9Ligands.sdf"

# =========================
# DIRECTORIES
# =========================

PROTEIN_OUTPUT_DIR="$DATA_DIR/pdbqt_receptor"
MOLECULE_DIR="$DATA_DIR/pdbqt_ligands/$PDB_ID"
TEMP_MOL2="$DATA_DIR/mol2_temp"

mkdir -p "$PROTEIN_OUTPUT_DIR"
mkdir -p "$MOLECULE_DIR"
mkdir -p "$TEMP_MOL2"

echo "======================================"
echo "SCORCH2 PDBQT Preparation"
echo "======================================"

# ============================================================
# 1. PREPARE RECEPTOR
# ============================================================

echo
echo "===== Preparing receptor ====="

PROTEIN_OUTPUT_DIR="$DATA_DIR/pdbqt_receptor"
PROTEIN_OUTPUT_PDBQT="$PROTEIN_OUTPUT_DIR/${PDB_ID}_protein.pdbqt"

mkdir -p "$PROTEIN_OUTPUT_DIR"

echo "Attempt 1: Preparing receptor directly from MOL2..."

# Try direct MOL2 preparation first
if "$ADFR_LOC/prepare_receptor" \
    -r "$PROTEIN_INPUT" \
    -o "$PROTEIN_OUTPUT_PDBQT"; then

    echo
    echo "Direct MOL2 preparation succeeded."
    echo "Protein ready:"
    echo "$PROTEIN_OUTPUT_PDBQT"

else

    echo
    echo "Direct MOL2 preparation failed."
    echo "Attempt 2: Converting MOL2 to PDB..."

    PROTEIN_PDB="$DATA_DIR/${PDB_ID}_protein.pdb"

    "$ADFR_LOC/obabel" "$PROTEIN_INPUT" \
        -O "$PROTEIN_PDB"

    echo
    echo "PDB created:"
    echo "$PROTEIN_PDB"

    echo
    echo "Preparing receptor from PDB..."

    if "$ADFR_LOC/prepare_receptor" \
        -r "$PROTEIN_PDB" \
        -o "$PROTEIN_OUTPUT_PDBQT"; then

        echo
        echo "PDB preparation succeeded."
        echo "Protein ready:"
        echo "$PROTEIN_OUTPUT_PDBQT"

    else

        echo
        echo "ERROR: Both receptor preparation methods failed."
        echo
        echo "The protein MOL2 could not be prepared by ADFR."
        echo "Check:"
        echo "  $PROTEIN_INPUT"
        echo
        exit 1

    fi
fi


# ============================================================
# 2. PREPARE LIGANDS
# ============================================================

echo
echo "===== Preparing ligands ====="

output_file_base=$(basename "$LIGAND_INPUT_SDF" .sdf)

# Remove old temporary MOL2 files
rm -f "$TEMP_MOL2"/*.mol2

# Convert SDF into individual MOL2 files
echo "Converting SDF to individual MOL2 files..."

"$ADFR_LOC/obabel" "$LIGAND_INPUT_SDF" \
    -O "$TEMP_MOL2/${output_file_base}_.mol2" \
    -m

# Move into temporary MOL2 directory
cd "$TEMP_MOL2"

counter=1

for file in $(find . -maxdepth 1 -name "*.mol2" -printf "%f\n" | sort -V); do

    # Get ligand title from MOL2
    ligand_title=$(awk '
        /^@<TRIPOS>MOLECULE$/ {
            getline
            print
            exit
        }
    ' "$file")

    # If no title was found, use the filename
    if [ -z "$ligand_title" ]; then
        ligand_title=$(basename "$file" .mol2)
    fi

    # Get ligand ID before the "|" if present
    ligand_id=$(echo "$ligand_title" | cut -d'|' -f1)

    # Replace spaces with underscores
    ligand_id=${ligand_id// /_}

    # Remove characters that are unsafe in filenames
    ligand_id=$(echo "$ligand_id" | sed 's/[^[:alnum:]_.-]/_/g')

    # Fallback if ligand ID is empty
    if [ -z "$ligand_id" ]; then
        ligand_id="$output_file_base"
    fi

    # Look for docking pose number
    pose_num=$(echo "$ligand_title" | sed -n 's/.*|dock\([0-9][0-9]*\).*/\1/p')

    # If no pose number exists, use counter
    if [ -z "$pose_num" ]; then
        pose_num="$counter"
    fi

    output_file="$MOLECULE_DIR/${PDB_ID}_${ligand_id}_pose${pose_num}.pdbqt"

    echo "Processing $file → $output_file"

    "$ADFR_LOC/prepare_ligand" \
        -l "$file" \
        -o "$output_file"

    counter=$((counter + 1))

done

cd "$DATA_DIR"

echo
echo "===== SCORCH2 Input Ready ====="

echo
echo "Receptor:"
echo "$PROTEIN_OUTPUT_PDBQT"

echo
echo "Ligands:"
echo "$MOLECULE_DIR"

echo
echo "Number of ligand PDBQT files:"
find "$MOLECULE_DIR" -name "*.pdbqt" | wc -l

echo
echo "======================================"
echo "Preparation complete!"
echo "======================================"
