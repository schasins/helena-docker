# usage: python startHelenaDockers.py --id=2357
# usage: python startHelenaDockers.py --id=2357 --vncpass=password --n=1 --r=1 --t=23
# docker run -t -p 5900:5900 -e VNC_SERVER_PASSWORD=password -e HELENA_PROGRAM_ID=2357 -e TIME_LIMIT_IN_HOURS=23 -e NUM_RUNS_ALLOWED_PER_WORKER=1 --user apps --privileged local/helena:0.0.1
# warning: killing this script also kills the containers it starts

import argparse, sys, os
import subprocess
import socket
import requests
import time

def isInUse(ip,port):
   s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
   try:
      s.connect((ip, int(port)))
      s.shutdown(2)
      return True
   except:
      return False

def toInt(a):
	try:
		return int(a)
	except:
		return 0

def newContainer(args, runid = False):
	# first pick a unique name
	dockers = subprocess.check_output(["docker","ps","-a","--format","\"{{.Names}}\""])
	ns = map(lambda x: x.strip("\""), dockers.split("\n"))
	numsFromNames = map(lambda x: toInt(x.split("_")[-1]), ns)
	maxNumSoFar = 0
	if len(numsFromNames) > 0:
		maxNumSoFar = max(maxNumSoFar, max(numsFromNames))
	name = "helena_" + str(maxNumSoFar + 1)

	foundAvailablePort = False
	port = None
	for i in range(5900,5999):
		portTaken = isInUse("0.0.0.0",i)
		if not portTaken:
			foundAvailablePort = True
			port = i
			break
	if (not foundAvailablePort):
		print "Sorry!  All the ports are in use already!  Can't start another container."
		return
	command = ["docker","run","-t","-p",str(i)+":"+str(i),"-e","VNC_SERVER_PASSWORD="+args.vncpass, \
		"-e","HELENA_PROGRAM_ID="+str(args.id),"-e","TIME_LIMIT_IN_HOURS="+str(args.t),"-e", \
		"NUM_RUNS_ALLOWED_PER_WORKER="+str(args.r),"--name",name,"--user","apps","--privileged","local/helena:0.0.1"]
	if runid:
		# add the run id
		command = command[:-4] + ["-e","HELENA_RUN_ID="+str(runid)] + command[-4:]
		print command
	return name, command

names = []

def main():
	global names

	parser=argparse.ArgumentParser()

	parser.add_argument('--vncpass', help='Provide a VNC password if you want to debug via VNC viewer', type=str, default="password")
	parser.add_argument('--id', help='The ID of the Helena program you want to run', type=int)
	parser.add_argument('--n', help='The number of parallel workers you want to use for the Helena run', type=int, default=1)
	parser.add_argument('--r', help='The number of runs of the Helena program you want to allow', type=int, default=1)
	parser.add_argument('--t', help='The time limit in hours on dockers\' existence', type=int, default=99999)

	args=parser.parse_args()

	if args.n < 1:
		print "Why are you trying to run this program with fewer than 1 workers?  Use 1 or more."
		exit()
	if args.n == 1:
		name, command = newContainer(args)
		names.append(name)
		subprocess.call(command)
	else:
		# first get the run id that we'll pass off to all the different containers
		# (remember, the skip block by default will skip over a subtask if a prior run has already *completed* the subtask
		# but will only skip over a *locked* but uncompleted subtask if it's been locked by a worker from the same run)
		# so all our parallel workers need to know that they're part of the same run
		# so we'll have them share a run id
		r = requests.post('http://helena-backend.us-west-2.elasticbeanstalk.com/newprogramrun', data = {"name": str(args.id)+"_"+str(args.n)+"_parallel_docker_lockBased", "program_id": args.id})
		output = r.json()
		runid = output["run_id"]
		procs = []
		for i in range(args.n):
			name, command = newContainer(args, runid)
			names.append(name)
			proc = subprocess.Popen(command)
			time.sleep(3)
			procs.append(proc)
		for p in procs:
			p.wait()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print 'Interrupted.  Killing docker container(s).'
        print names
        for name in names:
        	print "killing " + name
	        subprocess.call(["docker","kill",name])
	        subprocess.call(["docker","rm",name])
        try:
            sys.exit(0)
        except SystemExit:
            os._exit(0)

