## bam-downsampler.sh

Randomly downsample any number of BAM files 
so that they all contain the same number of reads.

The number of reads of the final down-sampled BAM files 
is determined by the BAM file with the lowest number of reads

**usage**

   ```
   bam-downsampler.sh /path/to/bamfile1.bam /path/to/bamfile2.bam /path/to/bamfile3.bam ...
   ```


**output**

Directory ```downsampled_bamfiles``` in the current directory containing the down-sampled BAM files

The number in the BAM filename is the number of reads the file was down-sampled to.



