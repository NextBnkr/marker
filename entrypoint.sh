#!/bin/bash
set -e

BUCKET="cgsejtyd4d"
PREFIX="models"
DEST="/root/.cache/datalab/models"
ENDPOINT="https://s3api-eu-ro-1.runpod.io"
REGION="eu-ro-1"

mkdir -p "$DEST"

echo "Listing objects from s3://$BUCKET/$PREFIX ..."
aws s3api list-objects-v2 \
  --bucket "$BUCKET" \
  --prefix "$PREFIX" \
  --endpoint-url "$ENDPOINT" \
  --region "$REGION" \
  --max-keys 1000 \
  --query 'Contents[].Key' --output text | tr '\t' '\n' | while read key; do
  
  # 去掉 prefix 得到相对路径
  rel="${key#$PREFIX/}"
  dest_path="$DEST/$rel"
  mkdir -p "$(dirname "$dest_path")"
  
  echo "Downloading $key ..."
  aws s3 cp "s3://$BUCKET/$key" "$dest_path" \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION"
done

echo "Download complete, starting server..."
exec .venv/bin/python ./marker_server.py
