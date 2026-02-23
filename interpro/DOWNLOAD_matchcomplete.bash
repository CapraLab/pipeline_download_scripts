#!/usr/bin/env bash

# SCRIPT ACTIONS
# 
# Download the huge match_complete.xml.gz from interpro
#
# After download, you MUST run infomap_humanonly.py in the PDBMap/data/interpro directory
# to create the much smaler match_humanonly.py file used by the PDBMap libraries and VUstruct
# pipeline
#
# USAGE (The download can take days.  Perhaps use a screen session on a stable node, or a slurm script)
#
# create a uniprot directory under your wherever/data directory structure.  Then:
#
#    $ cd wherever/data/interpro
#    $ ./DOWNLOAD_.matchcomplete.bash
#
# The downloads are large.  You should remove older downloaded versions as you can

## Set exit short-circuits for all download scripts.  
## GOAL: Do NOT process incomplete data
set -o errexit  # Stop script if a command exits with non zero
set -o nounset  # Treat unset variables as an error when substituting
set -o pipefail # the return value of a pipeline is the status of
                # the last command to exit with a non-zero status,
                # or zero if no command exited with a non-zero status

# Init Dictionary keys for final README and .YAML version record outputs
readonly MAINTAINER='chris.moth@vanderbilt.edu'
readonly DOWNLOAD_START=`date -Is`
readonly DOWNLOAD_SCRIPTFILE=${0##*/}
readonly DATE_YYMMDD=`date +%Y-%m-%d`

readonly LOG_FILE="$(pwd)/$DATE_YYMMDD/DOWNLOAD_interpro.log"

readonly PUBLICATION_DOI="https://doi.org/10.1038/s41586-021-03819-2"

readonly INTERPRO_BASE_URL="https://ftp.ebi.ac.uk/pub/databases/interpro/current_release/"
readonly XML_FILENAME="match_complete.xml.gz"

# When I create final README and YAML Files at close of these script, these variables are output
declare -a VERSION_KEYS=("MAINTAINER" "PUBLICATION_DOI" "DOWNLOAD_START" "DOWNLOAD_END" "DATE_YYMMDD" "LOG_FILE" "DOWNLOAD_SCRIPTFILE")

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
cmd="cp -pv $DOWNLOAD_SCRIPTFILE $DATE_YYMMDD/$DOWNLOAD_SCRIPTFILE.save" 
eval $cmd | tee -a $LOG_FILE
# echo "`date -Is`: `eval $cmd`" | tee -a $LOG_FILE

function download_interpro_xml_via_tempfile() {
  TMPFILE=$(mktemp $DATE_YYMMDD/tempfile.XXXXXXX)
  cmd="wget -O $TMPFILE --no-verbose --no-parent --directory-prefix=$DATE_YYMMDD -N --reject --no-host-directories --no-directories --timeout=100000 $INTERPRO_BASE_URL/$XML_FILENAME"
  echo "`date -Is`: Executing $cmd" | tee -a $LOG_FILE
  eval $cmd 2&>1 | tee -a $LOG_FILE
  # If wget returns non-0 the entire script must stop
  # Nonetheless in case of any mis-setting above, it is good to date stamp completion
  wget_exit_code=$?
  echo "`date -Is`: wget finished downloading $XML_FILENAME to $TMPFILE with code $wget_exit_code" | tee -a $LOG_FILE
  cmd="mv $TMPFILE $DATE_YYMMDD/$XML_FILENAME"
  echo "`date -Is`: Executing $cmd" | tee -a $LOG_FILE
  eval $cmd
}


download_interpro_xml_via_tempfile

### After success, create README and .yaml version files
readonly DOWNLOAD_END=`date -Is`
echo "$DOWNLOAD_END: Script Epilog: Creating README and interpro.yaml files" | tee -a $LOG_FILE

## README file first
for key in "${VERSION_KEYS[@]}"
do
    declare -n key_ref="$key"
    printf "%s: %s\n" $key $key_ref | tee -a $DATE_YYMMDD/README
done

## do entire file listing to the README
echo "Recording ls -lR of $DATE_YYMMDD/ in README" | tee -a $LOG_FILE
ls -lR $DATE_YYMMDD >>  $DATE_YYMMDD/README


## Create interpro.yaml
echo `date -Is`": Creating interpro.yaml file" | tee -a $LOG_FILE

rm -f $DATE_YYMMDD/interpro.yaml
for key in "${VERSION_KEYS[@]}"
do
    lower_case_key=${key,,}
    declare -n key_ref="$key"
    # Write out the key and the referenced string
    printf "%s: %s\n" $lower_case_key $key_ref | tee -a $DATE_YYMMDD/interpro.yaml
done

# Remove the current/ symlink and repoint it to the newly arrived download
cmd='rm -f current'
echo `date -Is`": $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE
# The _very_ last event is to create a symbolik link from current/ directory
cmd="ln -s $DATE_YYMMDD current"
echo `date -Is`": $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE

echo `date -Is` ": Download script is complete.  Results are in $DATE_YYMMDD/" | tee -a $LOG_FILE
