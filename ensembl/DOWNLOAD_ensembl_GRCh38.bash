#!/bin/bash
# SCRIPT ACTION
# Downloads the latest GRCh38 mysql database dump files from ensembl.org to a date-stamped directory
#
# This step is not required for VUStruct clients using the Vanderbilt-hosted ENSEMBL MariaDB/MySQL database
#
# USAGE
#
# create an ensembl directory under your wherever/data directory structure.  Then:
#
#    $ cd wherever/data/ensembl
#    $ ./DOWNLOAD_ensembl_GRCh38.bash
#
# STEPS AFTER DOWNLOAD:
# 1 DATABASE update: The subsequent database creation steps are at:
# https://useast.ensembl.org/info/docs/webcode/mirror/install/ensembl-data.html
#    (The needed"mysqlimport" commands can take a lot of time.)
# 2 Refresh the PERL API to match the new ENSEMBL version
# 3 Run test tools (not yet developed) to compare the ENSEMBL transcript amino acid sequences 
#   to uniprot sequences
#
# VERIFYING completeess of mysqlimport.
# You can get a good record count of each table in each database with commands like this:
#   SELECT table_name, table_rows   FROM INFORMATION_SCHEMA.TABLES   WHERE TABLE_SCHEMA = 'homo_sapiens_variation_108_38';
# Then, you can compare the linecounts of the source .sql files from the output of:
#   for file in *.txt.gz
#   do
#   echo -n "$file   "
#   zcat $file | wc -l
#   done



USER=`whoami`
DATE=`date +%Y-%m-%d`

mkdir -pv $DATE

# Copy this script and scripts in bin/ into the new directory
cp -v ${0##*/} $DATE

# Create README
echo "Creating $DATE/README"
echo "# GRCh38 Ensembl Mirror/Download" > $DATE/README
echo "# MAINTAINER: $USER" >> $DATE/README
echo "# EMAIL: chris.moth@vanderbilt.edu" >> $DATE/README


cmd="cd $DATE"
echo $cmd
eval $cmd
rsync -avR rsync://ftp.ensembl.org/ensembl/pub/current_mysql/./homo_sapiens_*_*/ ./
if [ $? -eq 0 ]
  then
#   Perform a cd -
    cmd="cd $OLDPWD"
    echo $cmd
    eval $cmd
    echo "# SUCCESFUL COMPLETION OF rsync" | tee -a $DATE/README
    echo "# LAST_UPDATE: $DATE" | tee -a $DATE/README
    echo "# UPDATE_CMD: ${0}" | tee -a $DATE/README
    echo "" >> $DATE/README
    echo "MANIFEST:" >> $DATE/README
    ls $DATE >> $DATE/README
else
    echo "********************* rsync FAILED *********************" | tee -a README
    echo "You need to restart.  Move directories to current date if necessary" | tee -a README
fi


# It is not clear that the "rsync" method will be maintained.
# I have left the wget lines below as alternatives to build a new .bash file from, if rsync is deprecated at ensembl.org
# See http://useast.ensembl.org/info/data/ftp/index.html/ 
# wget ftp://ftp.ensembl.org/pub/current_mysql/homo_sapiens_core_* -r -N -P $DATE -nH --cut-dirs 2
# wget ftp://ftp.ensembl.org/pub/current_mysql/homo_sapiens_variation_* -r -N -P $DATE -nH --cut-dirs 2
# If you get carried away you can add these to download EVERYTHING HUMAN
# wget ftp://ftp.ensembl.org/pub/current_mysql/homo_sapiens_* -r . -P $DATE -nH --cut-dirs 2 -N | tee -a $DATE/README

