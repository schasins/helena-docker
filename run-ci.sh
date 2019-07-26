#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

RUN_ID=$(curl -v -H "Content-Type: application/json" -d "{\"name\":\"CI\", \"program_id\":${PROGRAM_ID}}" -X POST "${SERVER_URL}/newprogramrun" | perl -ne '/"run_id":(\d+)/; print $1')
docker run -t -e NO_VNC=1 -e HELENA_SERVER_URL=$SERVER_URL -e ROW_BATCH_SIZE=1 -e HELENA_PROGRAM_ID=$PROGRAM_ID -e HELENA_RUN_ID=$RUN_ID -e TIME_LIMIT_IN_HOURS=23 -e NUM_RUNS_ALLOWED_PER_WORKER=1 -e DEBUG=1 --user apps --privileged helena:latest
# compare scraped data to expected results
RESULTS=$(curl -v $SERVER_URL/datasets/run/$RUN_ID)
if [ $(md5sum $RESULTS) -eq $(md5sum /test_results.csv) ]; then
    exit 0
fi
exit 1
