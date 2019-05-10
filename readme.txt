Quick start guide:

No need to even clone this repository!

(1) If not yet installed, install docker: https://www.docker.com/get-started

(2) Download the image tar, for example: wget https://github.com/schasins/helena-docker/raw/master/helena-image.tar

(3) Run the load command to load the tar: docker load --input helena-image.tar

(4) Start the program with the run command, for example: docker run -t -p 5900:5900 -e VNC_SERVER_PASSWORD=password -e HELENA_PROGRAM_ID=2357 -e HELENA_RUN_ID=1 -e TIME_LIMIT_IN_HOURS=23 -e NUM_RUNS_ALLOWED_PER_WORKER=1 --user apps --privileged local/helena:0.0.1

For developers:

docker run -t -p 5900:5900 -e VNC_SERVER_PASSWORD=password -e HELENA_PROGRAM_ID=2357 -e HELENA_RUN_ID=1 -e TIME_LIMIT_IN_HOURS=23 -e NUM_RUNS_ALLOWED_PER_WORKER=1 --user apps --privileged local/helena:0.0.1

docker build -t local/helena:0.0.1 .

docker kill $(docker ps -q)

docker save --output helena-image.tar local/helena:0.0.1

docker load --input helena-image.tar

wget https://github.com/schasins/helena-docker/raw/master/helena-image.tar
