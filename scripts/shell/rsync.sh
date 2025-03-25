dir1=$1
dir2=$2

dir1=$(realpath "$dir1")
dir2=$(realpath "$dir2")

exclude_from="./scripts/shell/exclude.txt"

echo -e "\nComparing directories:\n$dir1 \nand \n$dir2\n\n"

rsync -av --exclude-from=$exclude_from $dir1/.github $dir2
rsync -av --exclude-from=$exclude_from $dir1/modules $dir2
rsync -av --exclude-from=$exclude_from $dir1/patch $dir2
rsync -av --exclude-from=$exclude_from $dir1/scripts $dir2
rsync -av --exclude-from=$exclude_from $dir1/terraform $dir2
rsync -av --exclude-from=$exclude_from $dir1/.gitignore $dir2
