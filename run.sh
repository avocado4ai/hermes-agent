#!/bin/bash
cd "$(dirname "$0")"

TELEGRAM_BOT_TOKEN="8538300205:AAFiLxdc_FMGq43WhQ9GKiuud8AbDSCOpFs"
TELEGRAM_CHAT_ID="217441497"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d text="Hello from Hermes! Starting up..." > /dev/null

docker compose run --rm -it hermes "$@"
