#!/usr/bin/env bash
# Downloads the most up-to-date ClinVar associations from NCBI in VCF format
# From the sites documented at https://www.ncbi.nlm.nih.gov/clinvar/
# and https://ftp.ncbi.nlm.nih.gov/pub/clinvar/
# 
# Downloaded Data are stored in a new $DATE_YYMMDD/ directory
# which is symlinked to current/ directory at end of script
#
# Versioning
# ----------
# See https://www.ncbi.nlm.nih.gov/clinvar/docs/maintenance_use/
# 
# Clinvar data is updated every Monday
# This DOWNLOAD script extracts Clinvar's version date (the last Monday)
# from the filename returned from the ftp site
#
# A version record is created at the end of this script
# in clinvar.yaml and README file.  Per Clinvar documentation
#
# Recent changes
# --------------
# 2026-Feb-02: Output updated clinvar.yaml version file at end.  
#              to supplement README text
#              Removed command line support for deprecated GRCh37
#
# Post Download processing
# ------------------------
# Before running this script note that to break the downloaded .vcf file(s) into per-chromosome file, a manual step
# described at end of the script, is required

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
readonly CLINVAR_GENOME="GRCh38"      # Can be changed to GRCh37 to downoad deprecated Clinvar files
readonly DATE_YYMMDD=`date +%Y-%m-%d`
readonly LOG_FILE=$DATE_YYMMDD/DOWNLOAD_clinvar.log
readonly DOWNLOAD_SCRIPTFILE=${0##*/}

# When I create final README and YAML Files at close of these script, these variables are output
declare -a VERSION_KEYS=("MAINTAINER" "DOWNLOAD_START" "DOWNLOAD_END" "CLINVAR_GENOME" "DATE_YYMMDD" "LOG_FILE" "DOWNLOAD_SCRIPTFILE")


# All files are downloaded to current_working_directory/$DATE_YYMMDD
# At the end of the script a link from currnet_working_directory/current is made, for convenience
mkdir_cmd="mkdir -pv $DATE_YYMMDD"
result=`eval $mkdir_cmd`
touch $LOG_FILE
echo "$mkdir_cmd: $result" | tee $LOG_FILE

# Create a README file with only an error
# This README file is replace at end of successful download and CHROM split
echo "ERROR - $DOWNLOAD_SCRIPTFILE started but not run to completion" >  $DATE_YYMMDD/README
echo "        Review log file: $LOG_FILE" >> $DATE_YYMMDD/README

# There can be no version .yaml file until all is complete
rm -f $DATE_YYMMDD/clinvar.yaml

echo "Downloading Clinvar Variants for $CLINVAR_GENOME" | tee -a $LOG_FILE


# Copy this script into the new directory, as complete record
echo "`date -Is`: Saving this script as $DATE_YYMMDD/$DOWNLOAD_SCRIPTFILE.save" |tee -a $LOG_FILE
cp -pv $DOWNLOAD_SCRIPTFILE $DATE_YYMMDD/$DOWNLOAD_SCRIPTFILE.save | tee -a $LOG_FILE

### Download a consolidated clinvar variant database file from clinvar using wget
function wget_consolidated_clinvar_vcf_files_exit_if_error () {
  # Download GRCh38 or GRCh37 Clinvar variants per command line.  Exit the script if error
  cmd="wget --no-verbose --no-parent -P $DATE_YYMMDD/$CLINVAR_GENOME -N --reject -nH -nd --timeout=100000 ftp://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_$CLINVAR_GENOME/*.vcf*"
  echo `date -Is` Executing $cmd | tee -a $LOG_FILE
  eval $cmd 2>&1 | tee -a $LOG_FILE
  wget_returncd=$?
  echo `date -Is` "wget returned $wget_returncd"
  if [ $wget_returncd -ne 0 ]; then
      echo `date -Is` "Failure: wget was unable to download $CLINVAR_GENOME clinvar data" | tee -a $LOG_FILE
      exit 1
  fi
  echo `date -Is` 'Successful wget of clinvar files for ' $CLINVAR_GENOME ":" | tee -a $LOG_FILE
  ls -l $DATE_YYMMDD/$CLINVAR_GENOME/*.vcf* | tee $LOG_FILE
}

wget_consolidated_clinvar_vcf_files_exit_if_error

# An example/typical filename format for the downloaded file of interest
# where the final 8 numbers before .vcf are in YYYYMMDD format to reflect the version
# information from clinvar
# 2026-02-02/GRCh38/clinvar_20260201.vcf.gz
CLINVAR_VERSION_REGEX="$DATE_YYMMDD/$CLINVAR_GENOME/clinvar_(20[2-9][0-9][0-9][0-9][0-9][0-9]).vcf.gz"

# To get the actual name of the downloaded file on disk, remove the parenthesis which
# are incompatible with ls "glob" algorithm
CONSOLIDATED_CLINVAR_VCF_FILE=`ls -1 ${CLINVAR_VERSION_REGEX//[\(\)]/}`

if [[ $CONSOLIDATED_CLINVAR_VCF_FILE =~ $CLINVAR_VERSION_REGEX ]]; then
    CLINVAR_VERSION_YYMMDD=${BASH_REMATCH[1]}
    echo `date -Is` Clinvar version: $CLINVAR_VERSION_YYMMDD | tee -a $LOG_FILE
else
    echo `date -Is` "Unable to parse Clinvar version from" | tee -a $LOG_FILE
    echo "           filename: $CONSOLIDATED_CLINVAR_VCF_FILE" | tee -a $LOG_FILE
    echo "           with regex: $CLINVAR_VERSION_REGEX" | tee -a $LOG_FILE
    exit 1
fi

# echo $CONSOLIDATED_CLINVAR_VCF_FILE

# Use all but the trailing .vcf.gz as a base filename
# when we split apart the huge file into individual CHROM files
VCF_FILE_BASE="${CONSOLIDATED_CLINVAR_VCF_FILE%%.*}"

echo "The consolidated clinvar variant file just downloaded is $CONSOLIDATED_CLINVAR_VCF_FILE" | tee -a $LOG_FILE
echo "Counting the meta lines in $CONSOLIDATED_CLINVAR_VCF_FILE" | tee -a $LOG_FILE

# Now count the lines in the .vcf header
# This looks arcane - but the problem is that when we execute the inner read block, a
# new subprocess is essentially launched
echo --------------------- | tee -a $LOG_FILE
# zcat $CONSOLIDATED_CLINVAR_VCF_FILE | head -5 

set +o pipefail   # The next function generates a pipefail which is not an error

### Count the header lines in the downloaded file which begin
### with a # and are thus meta/header information
### We will copy these lines to each chromosome-specific break-out .vcf file
clinvar_vcf_header_linecount=$(zcat $CONSOLIDATED_CLINVAR_VCF_FILE | 
(
header_linecount=0
while IFS= read -r line; do
  if [ ${line:0:1} == '#' ]; then
     header_linecount=$((header_linecount+1))
  else
     break
  fi
done
echo $header_linecount # Return the count to caller, typically a number around 50
))

set -o pipefail # restore failure mode if a pipe is broken

echo "File $CONSOLIDATED_CLINVAR_VCF_FILE has $clinvar_vcf_header_linecount header lines which " | tee -a $LOG_FILE
echo "                                 will be copied to the per-chromosome output files."

### Split the downloaded consolidated file of variants into per-chromosome files
### This involves faithfully replicating header lines in each of the files
### Then 'grepping' the consolidated file for each chromosome
function split_individual_chromosomes() {
  for chrom in `seq 22` X Y; 
  do 
    SINGLE_CHROM_CLINVAR_FILE="$VCF_FILE_BASE.chr$chrom.vcf"
    echo `date -Is` "Splitting out Chr$chrom from $CONSOLIDATED_CLINVAR_VCF_FILE to $SINGLE_CHROM_CLINVAR_FILE" | tee -a $LOG_FILE
    # Copy over all the #-beginning header lines from the downloaded file to the new per-chrom break-out files
    set +o pipefail
    cmd="zcat $CONSOLIDATED_CLINVAR_VCF_FILE | head -$clinvar_vcf_header_linecount > $SINGLE_CHROM_CLINVAR_FILE"
    echo $cmd | tee -a $LOG_FILE
    eval $cmd 2>&1 | tee -a $LOG_FILE
    # Then copy over all the lines from the consolidated download file, starting with the specific chromosome
    set -o pipefail
    cmd='zgrep -P "^$chrom\t" $CONSOLIDATED_CLINVAR_VCF_FILE >> $SINGLE_CHROM_CLINVAR_FILE'
    echo $cmd | tee -a $LOG_FILE
    eval $cmd 2>&1 | tee -a $LOG_FILE
    
  done
}

### Call function above to split single downoaded file into per-chromosome files
split_individual_chromosomes

### After success, create README and .yaml version files
readonly DOWNLOAD_END=`date -Is`
echo "$DOWNLOAD_END: Script Epilog: Creating README and clinvar.yaml files" | tee -a $LOG_FILE

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


## Create clinvar.yaml
echo `date -Is`": Creating clinvar.yaml file" | tee -a $LOG_FILE

rm -f $DATE_YYMMDD/clinvar.yaml
for key in "${VERSION_KEYS[@]}"
do
    lower_case_key=${key,,}
    declare -n key_ref="$key"
    # Write out the key and the referenced string
    printf "%s: %s\n" $lower_case_key $key_ref | tee -a $DATE_YYMMDD/clinvar.yaml
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
