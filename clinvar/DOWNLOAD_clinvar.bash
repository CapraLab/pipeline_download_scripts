#!/bin/bash

# Downloads the most up-to-date ClinVar associations from NCBI in VCF format
# for either GRCh38 (default) or GRCh37 (via --genome GRCh37)
# First a very large 
# Before running this script note that to break the downloaded .vcf file(s) into per-chromosome file, a manual step
# described at end of the script, is required

CLINVAR_GENOME="GRCh38"
while [[ $# -gt 0 ]]; do
  case $1 in
    -g|--genome)
      CLINVAR_GENOME="$2"
      if [[ $CLINVAR_GENOME != "GRCh37" ]]; then
          echo "Failure.  Only -g alternative for default GRCh38 is GRCh37"
          exit 1
      fi

      shift # past argument
      shift # past value
      ;;

    -h|--help)
      echo "Download ClinVar variants"
      echo 'By default, GRCh38 genomic coordinates are downloaded.  You may revert to hg19/GRCh37 with "--genome GRCh37' 
      shift # past argument
      shift # past value
      ;;

    *)
      echo 'Valid options are -h for help, and "--genome GRCh37"'
      ;;
  esac
done

echo "Downloading Clinvar Variants for $CLINVAR_GENOME"

USER=`whoami`
DATE=`date +%Y-%m-%d`

# All files are downloaded to current_working_directory/$DATE
# At the end of the script a link from currnet_working_directory/current is made, for convenience
mkdir -p $DATE

# Copy this script into the new directory, as record
cp ${0##*/} $DATE


# Apparently there used to be a bin/ directory.  This seems gone now
# cp -R bin $DATE

# Download GRCh38 or GRCh37 Clinvar variants per command line.  Exit the script if error
cmd="wget --no-parent -P $DATE/$CLINVAR_GENOME -N --reject -nH -nd --timeout=100000 ftp://ftp.ncbi.nlm.nih.gov/pub/clinvar/vcf_$CLINVAR_GENOME/*.vcf*"
echo Executing $cmd
`$cmd`
if [ $? -ne 0 ]; then
    echo "Failure: Unable to download $CLINVAR_GENOME clinvar data"
    exit 1
fi
echo 'Successful wget of clinvar for ' $CLINVAR_GENOME

CONSOLIDATED_CLINVAR_VCF_FILENAME=`ls -1 $DATE/$CLINVAR_GENOME/clinvar_20[234][0-9][0-9][0-9][0-9][0-9].vcf.gz`
# Use all but the trailing .vcf.gz as a base filename
VCF_FILENAME_BASE=${CONSOLIDATED_CLINVAR_VCF_FILENAME:0:-7}
echo "The consolidated clinvar variant file just downloaded is $CONSOLIDATED_CLINVAR_VCF_FILENAME"

# Now count the lines in the .vcf header
# This looks arcane - but the problem is that when we execute the inner read block, a
# new subprocess is essentially launched
clinvar_vcf_header_linecount=$(zcat $CONSOLIDATED_CLINVAR_VCF_FILENAME | 
{
header_linecount=0
while IFS= read -r line
do
  if [ ${line:0:1} == '#' ]; then
     header_linecount=$((header_linecount+1))
  else
     break
  fi
done
echo $header_linecount
})

echo "The VCF file has $clinvar_vcf_header_linecount header lines which begin with #"

for chrom in `seq 22` X Y; 
do 
SINGLE_CHROM_CLINVAR_FILENAME="$VCF_FILENAME_BASE.chr$chrom.vcf"
echo "Splitting out Chr$chrom from $CONSOLIDATED_CLINVAR_VCF_FILENAME to $SINGLE_CHROM_CLINVAR_FILENAME"
# Copy over all the #-beginning header lines from the downloaded file to the new per-chrom break-out files
zcat $CONSOLIDATED_CLINVAR_VCF_FILENAME | head -$clinvar_vcf_header_linecount > $SINGLE_CHROM_CLINVAR_FILENAME
# Then copy over all the lines for the specific chromosome
zgrep -P "^$chrom\t" $CONSOLIDATED_CLINVAR_VCF_FILENAME >> $SINGLE_CHROM_CLINVAR_FILENAME
done

# Remove the current/ symlink and repoint it to the newly arrived download
rm -f current
ln -s $DATE current

# Create README
echo "# MAINTAINER: $USER" >> $DATE/README
echo "# EMAIL: chris.moth@vanderbilt.edu" >> $DATE/README
echo "# LAST_DOWNLOAD: $DATE" >> $DATE/README
echo "# UPDATE_CMD: ${0}" >> $DATE/README
#echo "# CITATION: PMID: XXXXXXX" >> $DATE/README

echo "" >> $DATE/README
echo "MANIFEST:" >> $DATE/README
ls $DATE >> $DATE/README

echo ""
echo "**************"
echo ""
echo "UPDATE ${DATE}/README"
echo ""
echo "**************"


#-----------------
