#!/bin/bash

########################################################
# See the README file which is created inline below
# README best explains the function of the script, its origin,
# and the directory heirarchy it maintains to mirror
# the pdb locallay
#
# INVOCATION:
# Typically DOWNLOAD_pdb.bash is run from a 'pdb' directory
# under a ...../data directory which houses sibling directories 
# for many data sources.  In our lab, invocation is done with:
#
#    $ cd /dors/capra_lab/data/pdb
#    $ ./DOWNLOAD_bash
#
# The rsyncs that are invoked may take some time.  
# Running in a "screen" background session, or as a slurm
# script, are strategies for coping with this.
########################################################

# The YYYY-MM-DD directory is where logs of the rsyncs can 
# be found.
DATE=`date +%Y-%m-%d`
mkdir -p $DATE

# The $USER variable populates a few of the outputs
USER=`whoami`

# DO NOT CHANGE MIRRORDIR unless you are deviating from
# the directory heirarchy discussed above, 
MIRRORDIR='.'
# mkdir -p $MIRRORDIR

# Copy this DOWNLOAD script into the local log directory
cp -v ${0##*/} $MIRRORDIR/$DATE

echo "Creating README file"
cat > README << ENDREADME 
DO NOT HAND-EDIT THIS README FILE

This file was last updated via $USER with the commands: 

   \$ cd `pwd` 
   \$ ${0}

MAINTAINER: Chris Moth
EMAIL: chris.moth@vanderbilt.edu

2019-01-02 Updated the script to:
  1) Mirror the source repo directory architecture
  2) Use rsync instead of sftp, with error checks
  3) Include mmCIF (and pdb) format structure and biounit files 

Rsync scripting inspired by the 'official' script here:
ftp://ftp.wwpdb.org/pub/pdb/software/rsyncPDB.sh

===========================================================================
PDB: Protein Databank

Contains essentially all protein structures currently available:
Includes xray crystallography, NMR, EM, cryo-EM, SAXS models
Theoretical models are not included in this refresh

The 'divided' and 'mmCIF' sub-directories load fastest.

Given pdb_id of 1ab2, the file is quickly found in the divided/../ab directory

For new code, avoid loading files from the sluggish 'all' subdirectories.

./structures/ are the entire structure as deposited in the PDB, typically the 
asymmetric unit which includes all chains which may or may not be 
physiologically correct

./biounits/ are annotated/predicted biological units which include only 
physiologically relevant complexes. Is not always accurate so double check 
that complex in biological unit is physiologically relevant with the 
structure's literature.  mmCIF format is only sparsely available for biounits

./current_collection/ = legacy softlink to the "pdb" "all" directories of 
structures and biounits.  Strongly discouraged due to slow loading time
of files from the 'all' sub-directories

LAST_UPDATE:  `date`
         BY:  $USER

MANIFEST
ENDREADME



############################################################################
# You should CHANGE THE NEXT THREE LINES to suit your local setup
############################################################################

LOGDIR=$MIRRORDIR/$DATE/log            # directory for storing logs
# RSYNC=<your local>/rsync             # location of local rsync
RSYNC=`command -v rsync`
if ! [ -x "$RSYNC" ]; then
  echo 'Fatal error:  No rsync binary is in the PATH of this system'
  exit 1
fi

echo "rsync binary is $RSYNC"

mkdir -pv $LOGDIR

##########################################################################################
#
#        YOU MUST UNCOMMENT YOUR CHOICE OF SERVER AND CORRESPONDING PORT BELOW
#
SERVER=rsync.wwpdb.org::ftp                                   # RCSB PDB server name
PORT=33444                                                    # port RCSB PDB server is using
#
#SERVER=rsync.ebi.ac.uk::pub/databases/rcsb/pdb-remediated     # PDBe server name
#PORT=873                                                      # port PDBe server is using
#
#SERVER=pdb.protein.osaka-u.ac.jp::ftp                         # PDBj server name
#PORT=873                                                      # port PDBj server is using
#
##########################################################################################

test_rsync_exit() {
    rsync_command=$1
    rsync_exit=$2
    if test $rsync_exit -eq 0
    then
        echo "rsync command exited successfully (code 0)"
    else
        echo "rsync command failed (code $rsync_exit) from directory" `pwd`
        echo "Command: $rsync_command"
        echo "Halting this script"
        exit $rsync_exit
    fi
}

echo "1 of 4: Download asymetric units in pdb format" | tee -a README
############################################################################
# Rsync only the PDB format coordinates  /pub/pdb/data/structures/divided/pdb (Aproximately 20 GB)
############################################################################
mkdir -vp $MIRRORDIR/structures/divided/pdb

cmd="${RSYNC} -rlpt -v -z --delete --port=$PORT ${SERVER}/data/structures/divided/pdb/ $MIRRORDIR/structures/divided/pdb > $LOGDIR/rsync_structures_pdb.stdout 2> $LOGDIR/rsync_structures_pdb.stderr"
echo $cmd >> README
echo $cmd | tee $LOGDIR/rsync_structures_pdb.stdout
eval $cmd
test_rsync_exit "$cmd" $?
echo "PDB Asymetric unit file count = `find $MIRRORDIR/structures/divided/pdb -type f -name \"*pdb*ent*\" | wc -l`" | tee -a README | tee -a $LOGDIR/rsync_structures_pdb.stdout
echo ""

echo "2 of 4: Download asymetric units in mmCIF format" | tee -a README
############################################################################
# Rsync only the mmCIF format coordinates  /pub/pdb/data/structures/divided/mmCIF (Aproximately 20 GB)
############################################################################
mkdir -vp $MIRRORDIR/structures/divided/mmCIF
cmd="${RSYNC} -rlpt -v -z --delete --port=$PORT ${SERVER}/data/structures/divided/mmCIF/ $MIRRORDIR/structures/divided/mmCIF > $LOGDIR/rsync_structures_mmCIF.stdout 2> $LOGDIR/rsync_structures_mmCIF.stderr"
echo $cmd >> README
echo $cmd | tee $LOGDIR/rsync_structures_mmCIF.stdout
eval $cmd
test_rsync_exit "$cmd" $?
echo "mmCIF Asymetric unit file count = `find $MIRRORDIR/structures/divided/mmCIF -type f -name \"*cif*\" | wc -l`" | tee -a README | tee -a $LOGDIR/rsync_structures_mmCIF.stdout
echo ""

echo "3 of 4: Download biounits in PDB format" | tee -a README
############################################################################
# Rsync only the PDB format coordinates  /pub/pdb/data/biounit/PDB/divided (Aproximately 20 GB)
############################################################################
mkdir -vp $MIRRORDIR/biounit/PDB/divided
cmd="${RSYNC} -rlpt -v -z --delete --port=$PORT ${SERVER}/data/biounit/PDB/divided/ $MIRRORDIR/biounit/PDB/divided > $LOGDIR/rsync_biounit_PDB.stdout 2> $LOGDIR/rsync_biounit_PDB.stderr"
echo $cmd >> README
echo $cmd | tee $LOGDIR/rsync_biounit_PDB.stdout
eval $cmd
test_rsync_exit "$cmd" $?
echo "PDB Biounit file count = `find $MIRRORDIR/biounit/PDB/divided/ -type f -name \"*pdb*\" | wc -l`" | tee -a README | tee -a $LOGDIR/rsync_biounit_PDB.stdout
echo ""


echo "4 of 4: Download biounits in mmCIF format" | tee -a README
############################################################################
# Rsync only the mmCIF format coordinates  /pub/pdb/data/biounit/mmCIF/divided (Aproximately 20 GB)
############################################################################
mkdir -vp $MIRRORDIR/biounit/mmCIF/divided
cmd="${RSYNC} -rlpt -v -z --delete --port=$PORT ${SERVER}/data/biounit/mmCIF/divided/ $MIRRORDIR/biounit/mmCIF/divided > $LOGDIR/rsync_biounit_mmCIF.stdout 2> $LOGDIR/rsync_biounit_mmCIF.stderr"
echo $cmd >> README
echo $cmd | tee $LOGDIR/rsync_biounit_mmCIF.stdout
eval $cmd
test_rsync_exit "$cmd" $?
echo "mmCIF Biounit file count = `find $MIRRORDIR/biounit/mmCIF/divided/ -type f -name \"*cif*\" | wc -l`" | tee -a README | tee -a $LOGDIR/rsync_biounit_mmCIF.stdout
echo "" | tee -a README

echo "Creating slow-loading pdb symlinks in $MIRRORDIR/structures/all/pdb " | tee -a README

mkdir -p $MIRRORDIR/structures/all/pdb
for divided_directory in `find $MIRRORDIR/structures/divided/pdb -type d`
do
for divided_file in `find $divided_directory -type f -name "*.gz"`
do
# Only add links for new symlinks, saving a little time and a lot of error messages
if test ! -L $MIRRORDIR/structures/all/pdb/`basename $divided_file`; then
ln -sv ../../$divided_file $MIRRORDIR/structures/all/pdb
fi
done
done


echo "Creating slow-loading biounit symlinks in $MIRRORDIR/biounit/all/pdb" | tee -a README
mkdir -p $MIRRORDIR/biounit/all/pdb
for divided_directory in `find $MIRRORDIR/biounit/PDB/divided -type d`
do
for divided_file in `find $divided_directory -type f -name "*.gz"`
do
# Only add links for new symlinks, saving a little time and a lot of error messages
if test ! -L $MIRRORDIR/biounit/all/pdb/`basename $divided_file`; then
ln -sv ../../$divided_file $MIRRORDIR/biounit/all/pdb
fi
done
done

echo `date`: ${0} | tee -a README
echo "Script has finished successfully" | tee -a README
#update the symlink
# rm current_collection
# ln -s $MIRRORDIR/ current_collection

