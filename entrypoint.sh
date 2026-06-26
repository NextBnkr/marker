#!/bin/bash
set -e

# =============================================================================
# RunPod marker-pdf 启动脚本
#
# 从阿里云 OSS 下载 surya 模型（阿里云 OSS 的 ListObjects 正常，可以直接 --recursive）
# =============================================================================

DEST="/root/.cache/datalab/models"
BUCKET="datalab-surya"
ENDPOINT="https://datalab-surya.oss-accelerate.aliyuncs.com"
REGION="oss-accelerate"

export AWS_REQUEST_CHECKSUM_CALCULATION=when_required

if [ -f "$DEST/layout/2025_09_23/manifest.json" ]; then
  echo "Models already cached, skipping download."
else
  echo "Downloading surya models from OSS..."
  mkdir -p "$DEST"
  aws s3 cp "s3://$BUCKET/" "$DEST/" \
    --endpoint-url "$ENDPOINT" \
    --region "$REGION" \
    --recursive
  echo "Download complete."
fi

exec .venv/bin/python ./marker_server.py
