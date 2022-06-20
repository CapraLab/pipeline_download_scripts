#!/usr/bin/env bash

# SCRIPT ACTIONS
# 
# Download Uniprot Identifiers, Filter to Human
# Download Sequence cross-references
# Download Uniparc sequences (cross reference UNIPARC IDs to Amino Acid sequences)
# The hard-coded "header" linecount in the downloaded sec_ac.txt file should be reviewed, found below in this script
#
# USAGE
#
# create a uniprot directory under your wherever/data directory structure.  Then:
#
#    $ cd wherever/data/uniprot
#    $ ./DOWNLOAD_uniprot.bash
#
# SQL Updates are likely needed
#
# For the PDBMap library to use these data, and fully support the PSB Pipeline,
# it is necessary to follow the download with SQL updates to the Idmapping and Uniparc tables
# Those are accomplished by scripts documented in the PDBMap/README.md
#
# The downloads are large.  You should remove older downloaded versions as you can

USER=`whoami`
DATE=`date +%Y-%m-%d`

mkdir -p $DATE

# Copy this script into the new directory
cp ${0##*/} $DATE

# For description of uniprot formats and downloads, see:
# https://www.uniprot.org/help/about
# http://www.uniprot.org/downloads

# get uniprot dataset - a file that contains info on ALL *reviewed* Uniprot KB entires for ALL species.
# We do not use unreviewed TrEMBL identifiers, available at a sibling directory
cmd="wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.dat.gz -P $DATE -nd -nH"
echo EXECUTING \$ $cmd
eval $cmd

# Reduce to human-only proteins by running a python program
# which outputs all lines of the file that relate to human uniprot IDs
# Detailed documentation of the uniprot_sprot.dat.gz file is
# https://www.uniprot.org/docs/userman.htm
#

echo "Launching embedded python program to extract human entries from $DATE/uniprot_sprot.dat.gz"
python - $DATE/uniprot_sprot.dat.gz $DATE/uniprot_sprot_human.dat << END_PROGRAM_HUMAN_EXTRACT
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

echo "Python program completed"
# rm $DATE/uniprot_sprot.dat.gz

# Pull the complete UniProt ID Mapping
wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/HUMAN_9606_idmapping.dat.gz -P $DATE -nH -nd

# Reduce the complete UniProt ID Mapping to Swiss-Prot
grep ^AC $DATE/uniprot_sprot_human.dat | awk '{for (i=2;i<=NF;i++)print "^"$i}' | tr -d ';' > $DATE/swissprot_human_uniprot_ids.txt

# Now we know the swissprot human uniprot IDs, filterthe total HUMAN file for just those
python - $DATE/swissprot_human_uniprot_ids.txt $DATE/HUMAN_9606_idmapping.dat.gz $DATE/HUMAN_9606_idmapping_sprot.dat.gz << END_PROGRAM_HUMAN_SPROT_ONLY
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

# Pull the limited UniProt primary AC -> dbref idmapping
wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/HUMAN_9606_idmapping_selected.tab.gz -P $DATE -nd -nH

# Decompress the idmapping
gunzip -f $DATE/HUMAN_9606_idmapping_selected.tab.gz

# Grab only the UniProt, RefSeq, PDB, Ensembl Transcript, and Ensembl Protein Columns
cut -f 1,2,4,6,20,21 $DATE/HUMAN_9606_idmapping_selected.tab > $DATE/HUMAN_9606_idmapping_UNP-RefSeq-PDB-Ensembl.tab

# Download the UniProt secondary AC -> primary AC mapping
# 2020-Oct deprecation note.  Nothing in the pipeline should be depending on these old cross-references
wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/knowledgebase/complete/docs/sec_ac.txt -P $DATE -nd -nH

# Download the UniProt uniref90 file (Added by Chris Moth 2019-03-25)
wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/uniref90.fasta.gz -P $DATE -nd -nH
wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/uniref90.xml.gz -P $DATE -nd -nH

# Download the (huge) UniProt UniParc file (Added by Chris Moth 2019-03-25)
wget -N --tries=100 --timeout=100000 ftp://ftp.uniprot.org/pub/databases/uniprot/current_release/uniparc/uniparc_active.fasta.gz -P $DATE -nd -nH



# Remove the header and convert whitespace to tab
sed '1,31d' $DATE/sec_ac.txt | sed 's/ \+ /\t/g' > $DATE/uniprot_sec2prim_ac.txt

# Cleanup the original files
# rm -f $DATE/sec_ac.txt

# Update current symbolic link
rm current
ln -s $DATE/ current

# Create README
echo "# MAINTAINER: $USER" >> $DATE/README
echo "# EMAIL: chris.moth@vanderbilt.edu" >> $DATE/README
echo "# LAST_UPDATE: $DATE" >> $DATE/README
echo "# UPDATE_CMD: ${0}" >> $DATE/README
echo "# CITATION: PDBID 14681372, 29425356" >> $DATE/README
echo "" >> $DATE/README
echo "Uniprot contains many different annotations for proteins and protein positions. Basically everything we know about a protein structure and function." > $DATE/README
echo "Downloaded here are the human uniprot set and the id mappings which is useful for converting different id types when intersecting data" > $DATE/README

echo "" >> $DATE/README
echo "" >> $DATE/README
echo "MANIFEST:" >> $DATE/README
ls $DATE >> $DATE/README
echo "**************"
echo ""
echo "UPDATE ${DATE}/README!
echo ""
echo "**************"
