#!/bin/sh
# sh ./dload_pics.sh https://habr.com/ru/post/567428/
wget \
     -A jpeg,gif,png,jpg \
     -nd \
     --level 1 \
     --page-requisites \
     --adjust-extension \
     --span-hosts \
     --convert-links \
     -e robots=off \
     --domains habrastorage.org,hsto.org \
     --no-parent \
    "$1"

# drop avatars
for FNAME in $(find . -type f -size -16k)
do
    rm "$FNAME"
done
