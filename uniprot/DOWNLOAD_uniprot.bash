#!/usr/bin/env bash

# SCRIPT ACTIONS
# 
# Download Uniprot Identifiers, Filter to Human
# Download Sequence cross-references
# Download Uniparc sequences (cross reference UNIPARC IDs to Amino Acid sequences)
# For description of uniprot formats and downloads, see:
# https://www.uniprot.org/help/about
# http://www.uniprot.org/downloads
#
# USAGE
#
# create a uniprot directory under your wherever/data directory structure.  Then:
#
#    $ cd wherever/data/uniprot
#    $ ./DOWNLOAD_uniprot.bash
#
#>>>>>>>>>>. SQL Updates are likely needed
#
# For the PDBMap library to use these data, and fully support the PSB Pipeline,
# it is necessary to follow the download with SQL updates to the Idmapping and Uniparc tables
# Those are accomplished by scripts documented in the PDBMap/README.md
#
# The downloads are large.  Take care to remove old versions
# 
# Versioning
# ----------
# Use the timestamp from the downloaded uniprot data to note the uniprot release.
# Uniprot notes a release every 2 or 3 months, and there is not a "version number" per se

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
readonly DATE_YYMMDD=`date +%Y-%m-%d`
readonly LOG_FILE=$DATE_YYMMDD/DOWNLOAD_uniprot.log
readonly DOWNLOAD_SCRIPTFILE=${0##*/}

# When I create final README and YAML Files at close of this script, these variables are output
declare -a VERSION_KEYS=("MAINTAINER" "DOWNLOAD_START" "DOWNLOAD_END" "UNIPROT_RELEASE" "DATE_YYMMDD" "LOG_FILE" "DOWNLOAD_SCRIPTFILE")

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
rm -f $DATE_YYMMDD/uniprot.yaml

# Copy this script into the new directory, as complete record
echo "`date -Is`: Saving this script as $DATE_YYMMDD/$DOWNLOAD_SCRIPTFILE.save" |tee -a $LOG_FILE
cp -pv $DOWNLOAD_SCRIPTFILE $DATE_YYMMDD/$DOWNLOAD_SCRIPTFILE.save | tee -a $LOG_FILE

# get uniprot dataset - a file that contains info on ALL *reviewed* Uniprot KB entires for ALL species.
# We do not use unreviewed TrEMBL identifiers, available at a sibling directory
cmd="wget --no-verbose --timestamping --no-verbose --tries=100 --timeout=100000 https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.dat.gz -P $DATE_YYMMDD -nd -nH"
echo "`date -Is`: EXECUTING $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE
# Get the uniprot release date from the file timestamp
UNIPROT_RELEASE=$(date -r "$DATE_YYMMDD/uniprot_sprot.dat.gz" '+%Y-%m-%d')
echo "UNIPROT_RELEASE is " $UNIPROT_RELEASE

# Reduce to human-only proteins by running a python program
# which outputs all lines of the file that relate to human uniprot IDs
# Detailed documentation of the uniprot_sprot.dat.gz file is
# https://www.uniprot.org/docs/userman.htm
#

echo "`date -Is`: Launching embedded python program to extract human entries from $DATE_YYMMDD/uniprot_sprot.dat.gz" | tee -a $LOG_FILE
python -u - $DATE_YYMMDD/uniprot_sprot.dat.gz $DATE_YYMMDD/uniprot_sprot_human.dat << END_PROGRAM_HUMAN_EXTRACT | tee -a $LOG_FILE
import sys,gzip

uniprot_sprot_all_entries_file = sys.argv[1]
uniprot_sprot_human_only_file = sys.argv[2]

line_count = 0
with gzip.open(uniprot_sprot_all_entries_file,'rt') as fin, \
  open(uniprot_sprot_human_only_file,'w') as fout:
    data_buffer = [] # We gather data.  Might be human, or not
    confirmed_human=False
    for line in fin:
        row = line.strip().split('   ')
        if row[0] == '//': # Terminator per https://www.uniprot.org/docs/userman.htm#Ter_line
            # Found new ID, if the previous entry was human,
            # flush the buffer
            if confirmed_human:
                for text_line in data_buffer:
                    fout.write(text_line)
            # Wait for confirmation that next entry is human
            confirmed_human = False
            # Clear the data buffer for the next entry
            data_buffer = []
        elif row[0] == 'OS' and row[1] == 'Homo sapiens (Human).':
            # Per https://www.uniprot.org/docs/userman.htm#OS_line
            # The current entry is human, flush these rows when finished
            confirmed_human = True
        # Store the row in the data buffer in case it is
        # human and needs to be printed
        data_buffer.append(line)
        line_count += 1
        if line_count % 1000000 == 0:
            print("%d million lines written to %s"%(line_count // 1000000,uniprot_sprot_human_only_file))
END_PROGRAM_HUMAN_EXTRACT

echo "`date -Is`: Python program to extract human uniprot IDs has completed" | tee -a $LOG_FILE
# rm $DATE_YYMMDD/uniprot_sprot.dat.gz

# Pull the complete Human UniProt ID Mapping
cmd="wget -N --no-verbose --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/HUMAN_9606_idmapping.dat.gz -P $DATE_YYMMDD -nH -nd"
echo "`date -Is`: EXECUTING $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE

#
# Reduce the complete UniProt ID Mapping to Swiss-Prot Curated uniprot ids
# IE Eliminate Trembl IDs
cmd="grep '^AC' 2026-02-21/uniprot_sprot_human.dat | awk '{for (i=2;i<=NF;i++) print \"^\"\$i}' | tr -d ';' > $DATE_YYMMDD/swissprot_human_uniprot_ids.txt"

echo "`date -Is`: EXECUTING $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE

# Now we know the swissprot human uniprot IDs, filterthe total HUMAN file for just those
python - $DATE_YYMMDD/swissprot_human_uniprot_ids.txt $DATE_YYMMDD/HUMAN_9606_idmapping.dat.gz $DATE_YYMMDD/HUMAN_9606_idmapping_sprot.dat.gz << END_PROGRAM_HUMAN_SPROT_ONLY | tee -a $LOG_FILE
import sys, gzip

swissprot_human_uniprot_ids_file  = sys.argv[1]
human_idmapping_file = sys.argv[2]
human_idmapping_sprot_only_file = sys.argv[3] # -< The final output

# Add all the curated human sprot uniprot IDs to a set
swissprot_curated_uniprot_ids = set()
with open(swissprot_human_uniprot_ids_file,'r') as ids_f:
    for line in ids_f:
        assert line[0] == '^'
        swissprot_curated_uniprot_ids.add(line[1:].strip())

print("%d swiss curated uniprot Ids extracted"%len(swissprot_curated_uniprot_ids))

# Now copy over each line from the "all file" if it is a swiss-curated uniprot ID line
with gzip.open(human_idmapping_file,'rt') as human_idmapping_all_f, gzip.open(human_idmapping_sprot_only_file,'wt') as human_idmapping_sprot_only_f:
    for line in human_idmapping_all_f:
        # Parse the source line into tab-delimited
        # unp at left, then id_type, then id
        unp,id_type,id = line.split('\t')

        # Then remove the isoform specific dashed number to check inclusion
        if unp.split('-')[0] in swissprot_curated_uniprot_ids:
            # DO NOT include the rare RefSeq_NT entry for NC_ mitochondrial transcripts
            # https://github.com/CapraLab/psbadmin/issues/65
            if id_type == 'RefSeq_NT' and id.startswith('NC_'):
                print("Skipping mitochondrial refseq xref: %s" % line.strip())
                continue # Skip the troublesome NC_ mitochondrial refseq crossref

            # Write the "good" swiss-curated idmapping file entry
            human_idmapping_sprot_only_f.write(line)
    
END_PROGRAM_HUMAN_SPROT_ONLY

echo 'Pull the limited UniProt primary AC -> dbref idmapping' | tee -a $LOG_FILE
cmd="wget -N --no-verbose --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/HUMAN_9606_idmapping_selected.tab.gz -P $DATE_YYMMDD -nd -nH"
echo "`date -Is`: EXECUTING $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE

echo Decompress the idmapping | tee -a $LOG_FILE
cmd="gunzip -f $DATE_YYMMDD/HUMAN_9606_idmapping_selected.tab.gz"
echo "`date -Is`: EXECUTING $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE

echo Excerpt only the UniProt, RefSeq, PDB, Ensembl Transcript, and Ensembl Protein Columns | tee -a $LOG_FILE
cmd="cut -f 1,2,4,6,20,21 $DATE_YYMMDD/HUMAN_9606_idmapping_selected.tab > $DATE_YYMMDD/HUMAN_9606_idmapping_UNP-RefSeq-PDB-Ensembl.tab"
echo "`date -Is`: EXECUTING $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE

# Download the UniProt secondary AC -> primary AC mapping
# The hard-coded "header" linecount in the downloaded sec_ac.txt file should be reviewed, found below in this script
# 2020-Oct deprecation note.  Nothing in the pipeline should be depending on these old cross-references
cmd="wget -N --no-verbose --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/knowledgebase/complete/docs/sec_ac.txt -P $DATE_YYMMDD -nd -nH"
echo "`date -Is`: EXECUTING $cmd" | tee -a $LOG_FILE
eval $cmd 2>&1 | tee -a $LOG_FILE

# Old Download the UniProt uniref90 file (Added by Chris Moth 2019-03-25)
#    Will reinstate when this is used in the pipeline
# wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/uniref90.fasta.gz -P $DATE_YYMMDD -nd -nH
# wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/uniref90.xml.gz -P $DATE_YYMMDD -nd -nH

# Old: Download the (huge) UniProt UniParc file (Added by Chris Moth 2019-03-25)
#      Now use Uniparc restapi to fill in sequence details
# wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/uniparc/uniparc_active.fasta.gz -P $DATE_YYMMDD -nd -nH



# Remove the header and convert whitespace to tab
sed '1,31d' $DATE_YYMMDD/sec_ac.txt | sed 's/ \+ /\t/g' > $DATE_YYMMDD/uniprot_sec2prim_ac.txt

# Cleanup the original files
# rm -f $DATE/sec_ac.txt

### After success, create README and .yaml version files
readonly DOWNLOAD_END=`date -Is`
echo "$DOWNLOAD_END: Script Epilog: Creating README and uniprot.yaml files" | tee -a $LOG_FILE

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


## Create uniprot.yaml
echo `date -Is`": Creating uniprot.yaml file" | tee -a $LOG_FILE

rm -f $DATE_YYMMDD/uniprot.yaml
for key in "${VERSION_KEYS[@]}"
do
    lower_case_key=${key,,}
    declare -n key_ref="$key"
    # Write out the key and the referenced string
    printf "%s: %s\n" $lower_case_key $key_ref | tee -a $DATE_YYMMDD/uniprot.yaml
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
