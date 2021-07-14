output=$1
shift
pd=$1
b160=$2
b1120=$3
mt1=$4
mt2=$5
mt3=$6
mt4=$7
mt5=$8
mt6=$9
echo $output
echo $pd
echo $b160
echo $mt1
echo $mt6
tmp_b1_subject_dir=$(mktemp -d)
tmp_subject_dir=$(mktemp -d)
cp $1 $tmp_subject_dir
cp $4 $tmp_subject_dir
cp $5 $tmp_subject_dir
cp $6 $tmp_subject_dir
cp $7 $tmp_subject_dir
cp $8 $tmp_subject_dir
cp $9 $tmp_subject_dir
cp $2 $tmp_b1_subject_dir
cp $3 $tmp_b1_subject_dir

for file in $tmp_subject_dir/*; do echo $file; done
