#!/bin/bash
#prep the data and run topup
#Usage:
#run_topup.sh inputs.txt
#Where inputs.txt contains lines of the following form, one per blip
#dwi_file bval_file bvec_file x y z t
#x y z t are lines as in the topup acquisition parameter file

inputs=$1

#INDIR=/bind/data_in
#OUTDIR=/bind/data_out

INDIR=/Users/roh17004/scratch/ibrain_dwi/100206 
OUTDIR=/Users/roh17004/Dropbox/hw4_solution/out

extract_b0 ()
{
	#extract low b0 values as separate volumes
	#extract_b0 file.bvals dwi.nii.gz prefix offset
	#assumes series starts with b0
	local bvals=( $( cat $1 ))
	local b0in=$2
	local prefix=$3
	local rr=$$
	local i=0
	local index_i=$4
	while [ $i -lt ${#bvals[@]} ]; do
		if [  ${bvals[$i]} -lt 51 ]; then
			fslroi $b0in `printf "${prefix}.${rr}.%03d $i 1" $i`
			let index_i=index_i+1 
		fi
		let i=i+1
		echo $(( index_i )) >> ${OUTDIR}/index.txt

	done

	fslmerge -t ${prefix} ${prefix}.${rr}.*
	rm ${prefix}.${rr}.*
}

#commands to merge everything
cmd_merge_dwi="fslmerge -t ${OUTDIR}/merged_dwi "
cmd_merge_bval="join "
cmd_merge_bvec="join "


offset=0
while read line; do
	a=( $( echo $line ) )
	echo ${INDIR}/${a[0]}
	cmd_merge_dwi="$cmd_merge_dwi ${INDIR}/${a[0]}"
	cmd_merge_bval="$cmd_merge_bval ${INDIR}/${a[1]}"
	cmd_merge_bvec="$cmd_merge_bvec ${INDIR}/${a[2]}"
	echo "${a[3]} ${a[4]} ${a[5]} ${a[6]}" >> ${OUTDIR}/acqparams.txt
	prefix=`printf "${OUTDIR}/blip_%03d" $offset`
	extract_b0 ${INDIR}/${a[1]} ${INDIR}/${a[0]} $prefix $offset
	let offset=offset+`fslnvols $prefix`
done <<< "$(cat $inputs)"

`$cmd_merge_dwi`
echo "$($cmd_merge_bvec)" > ${OUTDIR}/bvecs
echo "$($cmd_merge_bval)" > ${OUTDIR}/bvals

#merge b0
fslmerge -t ${OUTDIR}/b0_all ${OUTDIR}/blip_*

#remove top slice from HCP
fslroi ${OUTDIR}/b0_all ${OUTDIR}/b0_all_cropped 0 -1 0 -1 0 110 0 -1
fslroi ${OUTDIR}/merged_dwi ${OUTDIR}/merged_dwi_cropped 0 -1 0 -1 0 110 0 -1

#topup
cd $OUTDIR
topup --imain=b0_all_cropped --datain=acqparams.txt --config=b02b0.cnf --out=topup —iout=corrected_b0

#create brain mask
bet corrected_b0 brain -m



