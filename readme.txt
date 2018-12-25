docker run -t -p 5900:5900 -e VNC_SERVER_PASSWORD=password --user apps --privileged local/chrome:0.0.1

docker build -t local/chrome:0.0.1 .

docker kill $(docker ps -q)