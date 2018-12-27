docker run -t -p 5900:5900 -e VNC_SERVER_PASSWORD=password -e HELENA_PROGRAM_ID=2357 -e NUM_PARALLEL_WORKERS=1 -e TIME_LIMIT_IN_HOURS=23 -e NUM_RUNS_ALLOWED_PER_WORKER=1 --user apps --privileged local/chrome:0.0.1

docker run -t -p 5900:5900 -e VNC_SERVER_PASSWORD=password --user apps --privileged local/chrome:0.0.1

docker build -t local/chrome:0.0.1 .

docker kill $(docker ps -q)

docker save --output helena-image.tar local/chrome:0.0.1

docker load --input helena-image.tar

wget https://github.com/schasins/helena-docker/raw/master/helena-image.tar
