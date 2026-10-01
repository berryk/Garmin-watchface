#!/usr/bin/env bash
# Build the watch face with the fitness reporter switched on, for one device, on contabo-lon.
#
# The report endpoint and token are filled into a temporary copy of resources/properties.xml,
# so they never touch the repo. Output: ~/data/garmin-watchface/GMTWorldTime-<device>.prg,
# to be copied to GARMIN/APPS/ on the watch over USB.
#
#   scripts/build-reporting.sh              # venu441mm
#   scripts/build-reporting.sh venu445mm
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE=${1:-venu441mm}
IMAGE=ghcr.io/berryk/garmin-watchface/builder:latest
URL=${REPORT_URL:-https://garmin-watch.8landridgeroad.com/v1/report}
OUT_DIR=$HOME/data/garmin-watchface

export OP_SERVICE_ACCOUNT_TOKEN=${OP_SERVICE_ACCOUNT_TOKEN:-$(sudo -n cat /etc/op-service-account-token)}
TOKEN=$(op read "op://Homelab/contabo-lon/garmin-watch-report-token")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git ls-files -z | xargs -0 -I{} cp --parents {} "$work"
cp source/*.mc "$work/source/"   # include uncommitted sources
python3 - "$work/resources/properties.xml" "$URL" "$TOKEN" <<'EOF'
import sys
path, url, token = sys.argv[1:]
s = open(path).read()
for key, value in (("ReportUrl", url), ("ReportToken", token)):
    empty = f'<property id="{key}" type="string"></property>'
    assert empty in s, f"{key} placeholder missing"
    s = s.replace(empty, f'<property id="{key}" type="string">{value}</property>')
open(path, "w").write(s)
EOF

mkdir -p "$OUT_DIR"
docker run --rm -v "$work:/workspace" -v "$OUT_DIR:/out" -w /workspace "$IMAGE" bash -c "
  monkeyc -o /out/GMTWorldTime-$DEVICE.prg -f monkey.jungle -d $DEVICE -y /root/.garmin-keys/developer_key.der -w
  chown $(id -u):$(id -g) /out/GMTWorldTime-$DEVICE.prg
"
ls -la "$OUT_DIR/GMTWorldTime-$DEVICE.prg"
