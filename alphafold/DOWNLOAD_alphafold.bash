#!/usr/bin/env bash
# Purpose:
#   Download all human (taxid 9606) 3D protein models from AlphaFold DB versioned dataset.
#   All steps are logged to download.log. Script halts on any error.
#   Produces alphafold.yaml version information
#
#
# Three bash functions do the main work:
#    download_AF_tarfile_via_tempfile()
#         Downloads the correct .tar file from Alphafold ftp site
#    extract_model_files_from_tar_to_tmpdir()
#             and expands the Alphafold 2 modelset file for human canonical uniprot IDs
#    mv_model_files_to_directory_heirarchy()
#             enabling fast retrieval of models given uniprot id
#
# Versioning of AF2 models is entirely controlled by Alphafold in format v2, v3, ... v6....
# the final step in the script is to move all files into a faster-accessible directory heirarchy
#
## Set exit short-circuits for all download scripts.  
## GOAL: Do NOT process incomplete data
set -o errexit  # Stop script if a command exits with non zero
set -o nounset  # Treat unset variables as an error when substituting
set -e -o pipefail # the return value of a pipeline is the status of
                # the last command to exit with a non-zero status,
                # or zero if no command exited with a non-zero status

# Init Dictionary keys for final README and .YAML version record outputs
readonly MAINTAINER='chris.moth@vanderbilt.edu'
readonly DOWNLOAD_START=`date -Is`
readonly DOWNLOAD_SCRIPTFILE=${0##*/}
readonly DATE_YYMMDD=`date +%Y-%m-%d`

readonly LOG_FILE="$(pwd)/$DATE_YYMMDD/DOWNLOAD_alphafold.log"

readonly PUBLICATION_DOI="https://doi.org/10.1038/s41586-021-03819-2"

# Variables which construct the FTP target tar file for download
readonly HUMAN_PROTEOME_ID="UP000005640"
readonly HUMAN_TAXON_ID="9606"
readonly ALPHAFOLD_VERSION="v6"
readonly ALPHAFOLD_ROOTDIR="$(pwd)/human/$ALPHAFOLD_VERSION"
readonly TAR_FILENAME="$HUMAN_PROTEOME_ID"_"$HUMAN_TAXON_ID"_"HUMAN_$ALPHAFOLD_VERSION.tar"

# FTP site for Alphafold databasesdefault (common European FTP host for public bio datasets):
readonly FTP_BASE_URL="https://ftp.ebi.ac.uk/pub/databases/alphafold/${ALPHAFOLD_VERSION}/"

# When I create final README and YAML Files at close of these script, these variables are output
declare -a VERSION_KEYS=("MAINTAINER" "PUBLICATION_DOI" "DOWNLOAD_START" "DOWNLOAD_END" "ALPHAFOLD_VERSION" "ALPHAFOLD_ROOTDIR" "DATE_YYMMDD" "LOG_FILE" "DOWNLOAD_SCRIPTFILE")

# All files are downloaded to current_working_directory/$DATE_YYMMDD
# At the end of the script a link from currnet_working_directory/current is made, for convenience
mkdir_cmd="mkdir -pv $DATE_YYMMDD"
result=`eval $mkdir_cmd`
touch $LOG_FILE
echo "$mkdir_cmd: $result" | tee $LOG_FILE

# redirect all output to both console and log (append)
# exec > >(tee -a "$LOG_FILE") 2>&1
# echo test

# Copy this script into the new directory, as complete record
echo "`date -Is`: Saving this script as $DATE_YYMMDD/$DOWNLOAD_SCRIPTFILE.save" |tee -a $LOG_FILE
cp -pv $DOWNLOAD_SCRIPTFILE $DATE_YYMMDD/$DOWNLOAD_SCRIPTFILE.save | tee -a $LOG_FILE

function download_AF_tarfile_via_tempfile() {
  TMPFILE=$(mktemp $DATE_YYMMDD/tempfile.XXXXXXX)
  echo "`date -Is`: Downloading $TAR_FILENAME from $FTP_BASE_URL to $TMPFILE" | tee -a $LOG_FILE
  cmd="wget -O $TMPFILE --no-parent --directory-prefix=$DATE_YYMMDD -N --reject --no-host-directories --no-directories --timeout=100000 $FTP_BASE_URL/$TAR_FILENAME"
  echo "`date -Is`: Executing $cmd" | tee -a $LOG_FILE
  eval $cmd
  # If wget returns non-0 the entire script must stop
  # Nonetheless in case of any mis-setting above, it is good to date stamp completion
  wget_exit_code=$?
  echo "`date -Is`: wget finished downloading $TAR_FILENAME to $TMPFILE with code $wget_exit_code" | tee -a $LOG_FILE
  cmd="mv $TMPFILE $DATE_YYMMDD/$TAR_FILENAME"
  echo "`date -Is`: Executing $cmd" | tee -a $LOG_FILE
  eval $cmd
}

readonly TAR_EXTRACT_TMP=$DATE_YYMMDD/tmp

function extract_model_files_from_tar_to_tmpdir() {
  echo "`date -Is`: Extracting model files from $DATE_YYMMDD/$TAR_FILENAME" | tee -a $LOG_FILE
  mkdir -pv $TAR_EXTRACT_TMP
  cmd="tar --extract --verbose --directory=$TAR_EXTRACT_TMP --file=$DATE_YYMMDD/$TAR_FILENAME"
  # eval $cmd
  # echo here!!!!
  echo "`date -Is`: $cmd" | tee -a $LOG_FILE

# Run the command and count the lines output during the extraction as a filecount
  # set -e -o pipefail
  tar_count=$($cmd | wc -l)
  echo "$tar_count alphafold model files extracted"
}

function mv_model_files_to_directory_heirarchy() {
# The 5GB tar file does not have a directory heirarchy.  So, we iterate over the modeol filenames and we
# extract the uniprot ID from each filename, and then mkdir first2/second2/ and move the file there
# 
# This works because the filenames are in format AF-uniprot_id-Fn_vN.{cif,pdb}.gz
# Inspried by Bian Li's python script organize.py
  echo "`date -Is`: Moving model files into a directory heirarchy" | tee -a $LOG_FILE
  move_count=0
  for filename in $(tar tf $DATE_YYMMDD/$TAR_FILENAME) 
  do
    uniprot_id_first2=${filename:3:2}
    uniprot_id_second2=${filename:5:2}
    model_path="$ALPHAFOLD_ROOTDIR/$uniprot_id_first2/$uniprot_id_second2/"
    mkdir -p $model_path
    mv -v $TAR_EXTRACT_TMP/$filename $model_path | tee -a $LOG_FILE
    move_count=$((move_count+1))
  done

  printf "%d alphafold model files moved into subdirectories\n" $move_count | tee -a $LOG_FILE
  rmdir $TAR_EXTRACT_TMP
}

# Call the 3 main functions
download_AF_tarfile_via_tempfile
extract_model_files_from_tar_to_tmpdir
mv_model_files_to_directory_heirarchy

### After success, create README and .yaml version files
readonly DOWNLOAD_END=`date -Is`
echo "$DOWNLOAD_END: Script Epilog: Creating README and alphafold2.yaml files" | tee -a $LOG_FILE

## README file first
for key in "${VERSION_KEYS[@]}"
do
    echo $key
    declare -n key_ref="$key"
    printf "%s: %s\n" $key $key_ref | tee -a $DATE_YYMMDD/README
done

## do entire file listing to the README
echo "Recording ls -lR of $DATE_YYMMDD/ in README" | tee -a $LOG_FILE
ls -lR $DATE_YYMMDD >>  $DATE_YYMMDD/README


## Create alphafold2.yaml
echo `date -Is`": Creating alphafold2.yaml file" | tee -a $LOG_FILE

rm -f $DATE_YYMMDD/alphafold2.yaml
for key in "${VERSION_KEYS[@]}"
do
    lower_case_key=${key,,}
    declare -n key_ref="$key"
    # Write out the key and the referenced string
    printf "%s: %s\n" $lower_case_key $key_ref | tee -a $DATE_YYMMDD/alphafold2.yaml
done

# Remove the current/ symlink and repoint it to the newly arrived download
cmd='rm -f current'
echo `date -Is`": $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE
# The _very_ last event is to create a symbolik link from current/ directory
cmd="ln -s $DATE_YYMMDD current"
echo `date -Is`": $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE

echo `date -Is`": Download script is complete.  Results are in $DATE_YYMMDD/" | tee -a $LOG_FILE
