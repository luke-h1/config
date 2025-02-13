#!/bin/bash

empty_and_delete_bucket() {
    bucket_name=$1
    echo "Emptying bucket: $bucket_name"
    aws s3 rm s3://$bucket_name --recursive
    
    echo "Deleting bucket: $bucket_name"
    aws s3 rb s3://$bucket_name --force
    echo "Successfully deleted $bucket_name"
}

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 bucket-name-1 bucket-name-2 ..."
    exit 1
fi

for bucket in "$@"; do
    empty_and_delete_bucket "$bucket"
done
