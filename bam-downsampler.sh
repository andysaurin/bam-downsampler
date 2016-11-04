#!/bin/bash
#
# Author: Andy Saurin
# andrew.saurin at univ-amu.fr
#
# Takes 2 or more BAM files and downsamples them to the same number of mapped reads
#
# Requirements: samtools and bc
#

#check if samtools is installed
command -v samtools >/dev/null 2>&1 || { echo >&2 "Script requires samtools, but it's not installed or in your path.  Aborting."; exit 1; }

#check if bc is installed
command -v bc >/dev/null 2>&1 || { echo >&2 "The arbitrary precision calculator language 'bc' is required but not installed or in your path.  Aborting."; exit 1; }

pwd=$(pwd)
downsampled_bamdir="${pwd}/downsampled_bamfiles"


#the bamfiles array
BAMFILES=()
BAMFILE_NAMES=()
BAMFILE_COUNTS=()
i=0

#parse input bamfiles list
while [[ $# > 0 ]]
do

	bamfile="$1"
	if ! [[ -f $bamfile ]]; then
		echo "No such BAM file: "${bamfile}
		exit 1
	else
		if [[ "${bamfile##*.}" != "bam" ]]; then
			echo "No .bam extension in file: "${bamfile}
			exit 1
		else
			BAMFILES[$i]=$bamfile
			BAMFILE_NAMES[$i]=$(basename "$bamfile")
		fi
	fi

	((i++))
	shift

done

#echo ${#BAMFILES[@]}
#exit 0

if [[ ${#BAMFILES[@]} -le 1 ]]; then
	script=`basename "$0"`
	echo ""
	echo "Usage: $script file1.bam file2.bam ..."
	echo "A minimum of 2 BAM files are required."
	echo ""
	exit 1
fi

#get mapped counts in each bam file
for i in "${!BAMFILES[@]}"
do
	echo -n "Counting mapped reads in ${BAMFILE_NAMES[$i]} "
	bamfile=${BAMFILES[$i]}
	counts=$(samtools view -c -F 4 $bamfile)
	BAMFILE_COUNTS[$i]=${counts}
	echo " "${counts}
#	echo "key  : $i"
#	echo "value: ${BAMFILES[$i]}"
   # or do whatever with individual element of the array

done

#find the lowest amount of mapped reads that we will use to scale down to
# set the min reads to an very high value
minreads=1000000000000000000
for n in "${BAMFILE_COUNTS[@]}" ; do
    ((n < minreads)) && minreads=$n
done

echo ""
echo "Downsampling all BAM files to ~${minreads} mapped reads..."

if [[ ! -e $downsampled_bamdir ]]; then
	echo "Creating downsampled directory: ${downsampled_bamdir} "
	mkdir -p ${downsampled_bamdir}
fi

#check the otput directory now exists (previous would fail if no permission in current working directory)
if [[ ! -e $downsampled_bamdir ]]; then
	echo "Cannot create output directory: ${downsampled_bamdir}"
fi

#Downsample the files
for i in "${!BAMFILES[@]}"
do
	echo -n "${BAMFILE_NAMES[$i]} "

	fname=$(basename ${BAMFILE_NAMES[$i]} .bam)
	new_fname="${fname}.downsampled-${minreads}.bam"
	output_filepath="${downsampled_bamdir}/${new_fname}"

	if [[ ${BAMFILE_COUNTS[$i]} == ${minreads} ]]; then
		echo -n "${BAMFILE_COUNTS[$i]} == ${minreads} : Not downsampling, but will copy file over to downsampled directory...  "
		cp -f ${BAMFILES[$i]} ${output_filepath}

	else
		counts=${BAMFILE_COUNTS[$i]}
		seed=$((RANDOM%900+100))
		precision=6

		coeff=$(echo "scale=$precision; $seed+($minreads/$counts)" | bc -l )

		#downsampling command: samtools view -h -b -s ${coeff} INPUT.BAM > DOWNSAMPLED.BAM
		echo -n "(${BAMFILE_COUNTS[$i]} reads) downsampling to ${minreads} reads... "

		samtools view -h -b -s ${coeff} ${BAMFILES[$i]} > ${output_filepath}

		rc=$?;
		if [[ $rc != 0 ]]; then
			echo "FAILED"
			exit $rc;
		fi

		echo -n " Done. Sorting... "
		samtools sort ${output_filepath} ${output_filepath}.sorted

		rc=$?;
		if [[ $rc != 0 ]]; then
			echo "FAILED"
			exit $rc;
		fi

		mv -f ${output_filepath}.sorted.bam ${output_filepath}
		rc=$?;
		if [[ $rc != 0 ]]; then
			echo "FAILED"
			exit $rc;
		fi


	fi

	echo -n " Done. Indexing... "
	samtools index ${output_filepath}

	rc=$?;
	if [[ $rc != 0 ]]; then
		echo "FAILED"
		exit $rc;
	fi

	echo " Done"

done

echo ""
echo "All Done!"
echo "Downsampled BAM files are in ${downsampled_bamdir}"


exit 0

