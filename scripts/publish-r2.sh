#!/usr/bin/env bash
set -euo pipefail
OUT=${1:-bin/packages}
if ! command -v aws >/dev/null 2>&1; then echo "Install awscli v2" >&2; exit 1; fi
export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"; export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
ENDPOINT="https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com"
aws s3 cp "$OUT/" "s3://$R2_BUCKET/openwrt/23.05/" --endpoint-url "$ENDPOINT" --recursive --acl public-read --content-type text/plain || true
find "$OUT" -name 'Packages.gz' -exec aws s3 cp {} s3://$R2_BUCKET/openwrt/23.05/ --endpoint-url "$ENDPOINT" --acl public-read --content-type application/gzip --metadata-directive REPLACE \;
find "$OUT" -name 'Packages.sig' -exec aws s3 cp {} s3://$R2_BUCKET/openwrt/23.05/ --endpoint-url "$ENDPOINT" --acl public-read --content-type application/octet-stream --metadata-directive REPLACE \;
find "$OUT" -name '*.ipk' -exec aws s3 cp {} s3://$R2_BUCKET/openwrt/23.05/ --endpoint-url "$ENDPOINT" --acl public-read --content-type application/octet-stream --metadata-directive REPLACE \;
if [ -d dist/librespeed ]; then
  aws s3 cp dist/librespeed "s3://$R2_BUCKET/librespeed/23.05/" --endpoint-url "$ENDPOINT" --recursive --acl public-read --content-type application/octet-stream
fi
echo "Published to: $R2_PUBLIC_BASE/openwrt/23.05/"
