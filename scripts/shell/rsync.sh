source=$1
destination=$2
dryrun=$3

echo_usage(){
    echo "Usage: $0 source=<source> destination=<destination> dryrun=<true|false>"
}

if [[ "$source" != source=* ]]; then
    echo "Invalid source format: $source"
    echo_usage
    exit 1
else
    source=$(echo $source | cut -d'=' -f2)
fi

if [[ "$destination" != destination=* ]]; then
    echo "Invalid destination format: $destination"
    echo_usage
    exit 1
else
    destination=$(echo $destination | cut -d'=' -f2)
fi

if [[ "$dryrun" != dryrun=* ]]; then
    echo "Invalid dryrun format: $dryrun"
    echo_usage
    exit 1
else
    dryrun=$(echo $dryrun | cut -d'=' -f2)
fi

# check if dryrun is valid from true, false
if [[ "$dryrun" != "true" && "$dryrun" != "false" ]]; then
    echo "Invalid dryrun format: $dryrun"
    echo "Valid dryrun values are: true, false"
    echo_usage
    exit 1
fi

# if dryrun is true, set rsync to dry run
if [[ "$dryrun" == "true" ]]; then
    echo "Running in dry run mode"
    rsync_options="--dry-run"
else
    echo "Running in normal mode"
    rsync_options=""
fi

source=$(realpath "$source")
destination=$(realpath "$destination")

exclude_from="./scripts/shell/exclude.txt"

echo -e "\nExclude file:\n$exclude_from\n\n"

echo -e "\nComparing directories:\n$source \nand \n$destination\n\n"



rsync -av $rsync_options --exclude-from=$exclude_from $source/.github $destination
rsync -av $rsync_options --exclude-from=$exclude_from $source/modules $destination
rsync -av $rsync_options --exclude-from=$exclude_from $source/patch $destination
rsync -av $rsync_options --exclude-from=$exclude_from $source/scripts $destination
rsync -av $rsync_options --exclude-from=$exclude_from $source/terraform $destination
rsync -av $rsync_options --exclude-from=$exclude_from $source/.gitignore $destination
