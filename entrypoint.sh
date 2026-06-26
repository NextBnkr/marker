#!/bin/bash
set -e

# =============================================================================
# RunPod marker-pdf 启动脚本
#
# 从阿里云 OSS 逐文件下载 surya 模型，绕开 RunPod S3 的 ListObjectsV2
# 分页 bug（IsTruncated 永远为 true，导致 aws s3 cp --recursive 死循环）。
#
# 文件列表硬编码自 5 个模型的 manifest.json，已有文件自动跳过。
# =============================================================================

DEST="/root/.cache/datalab/models"
BUCKET="datalab-surya"
ENDPOINT="https://datalab-surya.oss-accelerate.aliyuncs.com"
REGION="oss-accelerate"

FILES=(
  # text_detection
  "text_detection/2025_05_07/model.safetensors"
  "text_detection/2025_05_07/preprocessor_config.json"
  "text_detection/2025_05_07/.gitattributes"
  "text_detection/2025_05_07/README.md"
  "text_detection/2025_05_07/training_args.bin"
  "text_detection/2025_05_07/config.json"
  # text_recognition
  "text_recognition/2025_09_23/.gitattributes"
  "text_recognition/2025_09_23/README.md"
  "text_recognition/2025_09_23/specials_dict.json"
  "text_recognition/2025_09_23/training_args.bin"
  "text_recognition/2025_09_23/special_tokens_map.json"
  "text_recognition/2025_09_23/vocab_math.json"
  "text_recognition/2025_09_23/specials.json"
  "text_recognition/2025_09_23/tokenizer_config.json"
  "text_recognition/2025_09_23/preprocessor_config.json"
  "text_recognition/2025_09_23/config.json"
  "text_recognition/2025_09_23/processor_config.json"
  "text_recognition/2025_09_23/model.safetensors"
  # layout
  "layout/2025_09_23/.gitattributes"
  "layout/2025_09_23/README.md"
  "layout/2025_09_23/specials_dict.json"
  "layout/2025_09_23/training_args.bin"
  "layout/2025_09_23/special_tokens_map.json"
  "layout/2025_09_23/vocab_math.json"
  "layout/2025_09_23/specials.json"
  "layout/2025_09_23/tokenizer_config.json"
  "layout/2025_09_23/preprocessor_config.json"
  "layout/2025_09_23/config.json"
  "layout/2025_09_23/processor_config.json"
  "layout/2025_09_23/model.safetensors"
  # table_recognition
  "table_recognition/2025_02_18/model.safetensors"
  "table_recognition/2025_02_18/config.json"
  "table_recognition/2025_02_18/README.md"
  "table_recognition/2025_02_18/.gitattributes"
  "table_recognition/2025_02_18/preprocessor_config.json"
  # ocr_error_detection
  "ocr_error_detection/2025_02_18/model.safetensors"
  "ocr_error_detection/2025_02_18/tokenizer_config.json"
  "ocr_error_detection/2025_02_18/special_tokens_map.json"
  "ocr_error_detection/2025_02_18/config.json"
  "ocr_error_detection/2025_02_18/tokenizer.json"
  "ocr_error_detection/2025_02_18/README.md"
  "ocr_error_detection/2025_02_18/vocab.txt"
  "ocr_error_detection/2025_02_18/.gitattributes"
)

echo "============================================"
echo "Downloading surya models from OSS"
echo "============================================"

for key in "${FILES[@]}"; do
  dest_path="$DEST/$key"
  mkdir -p "$(dirname "$dest_path")"

  if [[ -f "$dest_path" ]]; then
    echo "[skip] $key"
  else
    echo "[download] $key"
    aws s3 cp "s3://$BUCKET/$key" "$dest_path" \
      --endpoint-url "$ENDPOINT" \
      --region "$REGION" \
      --no-progress
  fi
done

echo "============================================"
echo "All models ready, starting server..."
echo "============================================"

exec .venv/bin/python ./marker_server.py
