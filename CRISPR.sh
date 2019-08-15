#!/bin/bash
#################################################
# Script to execute the CRISPR Analyzer Pipeline
# Roberto Villegas-Diaz
# roberto.villegasdiaz@sdstate.edu
# May 5th, 2018
################################################
usage="${0##*/} [-c N] [-d WD] [-e N] [-h] [-n STRING] [-r 0/1] [-s STRING] -- program to execute the CRISPR AnalyzeR Pipeline

where:
    -c  number of cores (default=8) [cutadapt]
    -d  working directory
    -e  error tolerance (default=0.20) [cutadapt]
    -h  show this help text
    -n  name (prefix) of the output file (default=IgG2A_RBC_uptake) [mageck count]
    -r  attemp to restart the execution (default=0)
    -s  sequence to be trimmed (default=CGAAACACCG...gttttagagc) [cutadapt]"
start=$(date +%s)
c=8 # default values
e=0.2
n='IgG2A_RBC_uptake'
r=0
s='CGAAACACCG...gttttagagc'
# Parses the parameters passed during function invokation
while getopts 'hc:d:e:n:r:s:' option; do
  case "$option" in
    c) c=$OPTARG
       ;;
    d) d=$OPTARG
       ;;
    e) e=$OPTARG
       ;;
    h) echo "$usage"
       exit
       ;;
    n) n=$OPTARG
       ;;
    r) r=$OPTARG
       ;;
    :) printf "missing argument for -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
shift $((OPTIND - 1))
if [ -z $d ]
	then
		echo "$usage"
		exit
fi

echo "Entry working directory: '${d}'"
cd $d

## declare an array variable
arr=("High" "Input" "Low" "Pre-sort")
sampnames='High,Input,Low,Pre'
## now loop through the above array
for i in "${arr[@]}"
do
	echo "- Entry $i"
	cd $i
	for j in {1..4}
	do
		if [ ! -f t$i$j.fastq ] || [ $r = '0' ]; then
			echo "cutadapt -g ${s} -o t$i$j.fastq *_L*[0-9]${j}_*.fastq.gz -m 15 --discard-untrimmed -e ${e} --cores=${c}"		 
			cutadapt -g $s -o t$i$j.fastq *_L*[0-9]${j}_*.fastq.gz -m 15 --discard-untrimmed -e $e --cores=$c		 
		else
			echo "The file t$i$j.fastq already exists"
		fi
	done
	cd ..
	echo " "
done

echo "Done with CUTADAPT"
echo "Preparing files for MaGeCK"
mkdir -p "Trimmed"
inputs=''
for i in "${arr[@]}"
do
	for j in $i/t*.fastq
        do
			inputs="$(echo ${inputs}'../'$j',')"
        done
	inputs=${inputs::-1} # Deletes the last comma of the string
	inputs=${inputs}' ' # Adds a blank at the tail of the string
done
echo "Files are ready to be run with MaGeCK"
echo " "
cd "Trimmed"
cp -r $LATEX_LIBS/* .
echo "Executing MaGeCK"
echo "mageck count -l $BRIE_LIB -n ${n} --sample-label  ${sampnames}  --trim-5 0 --fastq  ${inputs}  --pdf-report"
mageck count -l $BRIE_LIB -n ${n} --sample-label  ${sampnames}  --trim-5 0 --fastq  ${inputs}  --pdf-report

echo "Done with MaGeCK"
echo " "
cd ..
comp=("Low/High" "Pre/Low" "Pre/High" "Input/Pre")
for i in "${comp[@]}"
do
	echo "Creating the ${i} comparison"
	c1="$(echo $i | awk -F/ '{print $1}')"
	c2="$(echo $i | awk -F/ '{print $2}')"
	name=$c1$c2
	mkdir -p $name
        cp -r Trimmed/*.count.txt $name
	cd $name
	cp -r $LATEX_LIBS/* .
	echo "mageck test -k *.count.txt -t $c1 -c $c2 -n $name --remove-zero both --pdf-report"
	mageck test -k *.count.txt -t $c1 -c $c2 -n $name --remove-zero both --pdf-report
	cd ..
	echo " "
done

end=$(date +%s)
runtime=$((end-start))
echo 'Runtime: '$runtime' s'

#  rm -r InputPre LowHigh PreHigh PreLow
