#!/bin/sh
# sh ./dload_pics.sh

pwd=$(pwd)
dir=$(basename "$pwd")
echo "$dir"

cd ..
file=$(ls "$dir "*.md)
cd "$pwd"
echo "Markdown file found: $file"

IMAGES=$(cat "../$file" | grep '!\[\](' | sed -E 's/!\[\]\((https:\/\/.*)\)/\1/')
for IMAGE in $IMAGES
do
    echo "Download image $IMAGE"
    wget -c "$IMAGE"
done
