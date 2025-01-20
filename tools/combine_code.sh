#!/bin/bash

# 除外する拡張子を設定
EXCLUDE_ARGS=""
if [ -f .exclude_extensions ]; then
  while IFS= read -r ext; do
    if [[ "$ext" != "" && "$ext" != \#* ]]; then
      EXCLUDE_ARGS+=" -not -name '*$ext'"
    fi
  done < .exclude_extensions
fi

# コミットIDを取得
COMMIT_ID=$(git rev-parse --short HEAD)

# リポジトリ名を取得 (GitHub Actions 環境とローカル環境で異なる)
if [ -n "$GITHUB_REPOSITORY" ]; then
  REPO_NAME=$(echo "$GITHUB_REPOSITORY" | tr '/' '_')
else
  read -p "Enter repository name (used for output file name): " REPO_NAME
fi

# 出力ファイル名を指定
OUTPUT_FILE="${REPO_NAME}_combined_code_${COMMIT_ID}.txt"

# 結合処理
echo "# Combined Source Code (Repo: $REPO_NAME, Commit: $COMMIT_ID)" > "$OUTPUT_FILE"
find . -type f -not -path "./.git/*" -not -path "./$OUTPUT_FILE" $EXCLUDE_ARGS -print | while IFS= read -r file; do
  echo "---" >> "$OUTPUT_FILE"
  echo "File: $file" >> "$OUTPUT_FILE"
  echo "\`\`\`" >> "$OUTPUT_FILE"
  cat "$file" >> "$OUTPUT_FILE"
  echo "\`\`\`" >> "$OUTPUT_FILE"
done

echo "Combined code written to: $OUTPUT_FILE"