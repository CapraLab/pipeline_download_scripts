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

USER=`whoami`
DATE=`date +%Y-%m-%d`

cmd="mkdir -pv $DATE"
echo Executing: $cmd
eval $cmd

# Copy this script into the new directory
cp -v ${0##*/} $DATE

# For description of formats and downloads, see:
# https://www.uniprot.org/help/about
# http://www.uniprot.org/downloads

#get uniprot dataset
# OLD IDEA wget -N --tries=100 --timeout=100000 ftp://ftp.ebi.ac.uk/pub/databases/interpro/current/match_complete.xml.gz -P $DATE -nd -nH
cmd='wget -N --tries=100 --timeout=100000 https://ftp.ebi.ac.uk/pub/databases/interpro/current_release/match_complete.xml.gz -P $DATE -nd -nH'
echo Executing: $cmd
eval $cmd
echo Updating \'current\' symbolic link tp referemce $DATE
cmd='rm -f current'
echo Executing: $cmd
eval $cmd

cmd="ln -s $DATE/ current"
echo Executing: $cmd
eval $cmd

# Create README
echo "# MAINTAINER: $USER" >> $DATE/README
echo "# EMAIL: chris.moth@vanderbilt.edu" >> $DATE/README
echo "# LAST_UPDATE: $DATE" >> $DATE/README
echo "# UPDATE_CMD: ${0}" >> $DATE/README
echo "# CITATION: PDBID 33156333" >> $DATE/README
echo "" >> $DATE/README
echo "Follow with post processing to create match_human.xml. This file is input to the psb pipeline's report gneerator." >> $DATE/README

echo "" >> $DATE/README
echo "" >> $DATE/README
echo "MANIFEST:" >> $DATE/README
ls $DATE >> $DATE/README
echo "**************"
echo ""
echo "UPDATE ${DATE}/README!"
echo ""
echo "**************"
