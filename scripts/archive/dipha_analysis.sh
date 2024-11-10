#!/bin/bash

set -e

PWD_PATH=`pwd`
DIPHA_PATH="$1"
# IN_FOLDER="data/exp_pro/images_for_dipha"
IN_FOLDER=$2

# OUT_FOLDER="data/exp_pro/dipha_results_RGB/Artysta"
OUT_FOLDER="data/exp_pro/dipha_results_RGB/wystawa_fejkowa"

for file in ${IN_FOLDER}/*.jpg; do
    # for file in ${IN_FOLDER}/*.complex; do
    OUTPUT_FILE=$(echo $file| sed 's:\.jpg::g')
    
    # TODO the pieces below could be refactored to remove IN_FOLDER
    echo "Output file:" $OUTPUT_FILE
    OUTPUT_FILE=$(echo $OUTPUT_FILE| sed 's:data::g')
    echo "Output file:" $OUTPUT_FILE
    OUTPUT_FILE=$(echo $OUTPUT_FILE| sed 's:exp_pro::g')
    echo "Output file:" $OUTPUT_FILE
    OUTPUT_FILE=$(echo $OUTPUT_FILE| sed 's:images_for_dipha::g')
    echo "Output file:" $OUTPUT_FILE
    OUTPUT_FILE=$(echo $OUTPUT_FILE| sed 's:_RGB::g')
    echo "Output file:" $OUTPUT_FILE
    # OUTPUT_FILE=$(echo $OUTPUT_FILE| sed 's:Artysta::g')
    OUTPUT_FILE=$(echo $OUTPUT_FILE| sed 's:wystawa_fejkowa::g')
    echo "Output file:" $OUTPUT_FILE
    OUTPUT_FILE=$(echo $OUTPUT_FILE| sed 's:/::g')
    echo "Output file:" $OUTPUT_FILE
    
    echo "File: " $file
    echo "Output file:" $OUTPUT_FILE
    echo "Output file with path:" $OUT_FOLDER/$OUTPUT_FILE
    
    $DIPHA_PATH $file $OUT_FOLDER/"${OUTPUT_FILE}"
done

echo "===-===-===-===-"

# ===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-===-
# ===-
echo "Finished DIPHA processing."
