#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

PROGRAM_ID="$1"
NUM_WORKERS="$2"
[ $# -eq 0 ] && { echo "Usage: $0 program_id num_workers"; exit 1; }

EXTENSION_ID=khjmjgndbklcflgokmgdjigioindpodn
HELENA_SERVER_URL=http://helena-backend.us-west-2.elasticbeanstalk.com
AWS_ACCOUNT_ID=042666389891
REGION=us-west-2
INSTANCE_TYPE=t2.2xlarge
MIN_MEM_MB=128
CLUSTER_NAME=helena
CLUSTER_SIZE=1
KEY_PAIR=helena-server
IMAGE_NAME=helena
IMAGE_TAG=latest
REPOSITORY_IMAGE_NAME=${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${IMAGE_NAME}:${IMAGE_TAG}

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI_launch_latest.html
# workaround for no associative arrays in bash 3: https://stackoverflow.com/a/22151682/6837245
region2ami() {
    case $1 in
        'us-east-2') echo 'ami-00cffcd24cb08edf1';;
        'us-east-1') echo 'ami-0bc08634af113cccb';;
        'us-west-1') echo 'ami-05cc68a00d392447a';;
        'us-west-2') echo 'ami-0054160a688deeb6a';;
        'ap-east-1') echo 'ami-087f0e5fc12e0bc43';;
        'ap-northeast-1') echo 'ami-00f839709b07ffb58';;
        'ap-northeast-2') echo 'ami-0470f8828abe82a87';;
        'ap-south-1') echo 'ami-0d143ad35f29ad632';;
        'ap-southeast-1') echo 'ami-0c5b69a05af2f0e23';;
        'ap-southeast-2') echo 'ami-011ce3fbe73731dfe';;
        'ca-central-1') echo 'ami-039a05a64b90f63ee';;
        'eu-central-1') echo 'ami-0ab1db011871746ef';;
        'eu-north-1') echo 'ami-036cf93383aba5279';;
        'eu-west-1') echo 'ami-09cd8db92c6bf3a84';;
        'eu-west-2') echo 'ami-016a20f0624bae8c5';;
        'eu-west-3') echo 'ami-0b4b8274f0c0d3bac';;
        'sa-east-1') echo 'ami-04e333c875fae9d77';;
    esac
}

AMI_ID=$(region2ami $REGION)
RUN_ID=$(curl -v -H "Content-Type: application/json" -d "{\"name\":\"ECS_${PROGRAM_ID}_${NUM_WORKERS}\", \"program_id\":${PROGRAM_ID}}" -X POST "${HELENA_SERVER_URL}/newprogramrun" | perl -ne '/"run_id":(\d+)/; print $1')

cat > /tmp/ecs-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

cat > /tmp/role-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeRepositories",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:ListImages",
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTask",
        "ecs:StartTelemetrySession",
        "ecs:SubmitContainerStateChange",
        "ecs:SubmitTaskStateChange",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF

cat > /tmp/user-data.sh <<EOF
#!/bin/bash
echo 'ECS_CLUSTER=$CLUSTER_NAME' >> /etc/ecs/ecs.config
EOF

cat > /tmp/task-definition.json <<EOF
{
  "family": "${CLUSTER_NAME}_${PROGRAM_ID}",
  "networkMode": "bridge",
  "containerDefinitions": [
    {
      "image": "$REPOSITORY_IMAGE_NAME",
      "name": "helena",
      "memoryReservation": $MIN_MEM_MB,
      "cpu": 0,
      "essential": true,
      "privileged": true,
      "user": "apps",
      "portMappings": [
        {
          "containerPort": 5900
        }
      ],
      "environment" : [
        { "name" : "VNC_SERVER_PASSWORD", "value" : "password" },
        { "name" : "HELENA_EXTENSION_ID", "value" : "$EXTENSION_ID" },
        { "name" : "HELENA_PROGRAM_ID", "value" : "$PROGRAM_ID" },
        { "name" : "HELENA_RUN_ID", "value" : "$RUN_ID" },
        { "name" : "HELENA_SERVER_URL", "value" : "$HELENA_SERVER_URL" },
        { "name" : "ROW_BATCH_SIZE", "value" : "1" },
        { "name" : "TIME_LIMIT_IN_HOURS", "value" : "23" },
        { "name" : "NUM_RUNS_ALLOWED_PER_WORKER", "value" : "1" },
        { "name" : "DEBUG", "value" : "1" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-create-group": "true",
          "awslogs-group": "awslogs-helena",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "${CLUSTER_NAME}_${PROGRAM_ID}"
        }
      }
    }
  ]
}
EOF

aws --region $REGION ecr create-repository --repository-name $IMAGE_NAME || true
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
DOCKER_LOGIN=$(aws --region $REGION ecr get-login --no-include-email)
eval "$DOCKER_LOGIN"
IMAGE_ID=$(docker images | grep "$IMAGE_NAME" | awk '{print $3}' | head -1)
docker tag $IMAGE_ID $REPOSITORY_IMAGE_NAME
docker push $REPOSITORY_IMAGE_NAME

# if cluster doesn't exist, create it
CLUSTER_RESP=$(aws --region $REGION ecs describe-clusters --cluster $CLUSTER_NAME)
if [[ "$CLUSTER_RESP" == *"MISSING"* || "$CLUSTER_RESP" == *"INACTIVE"* ]]; then
  aws --region $REGION iam create-role --role-name ecsRole --assume-role-policy-document file:///tmp/ecs-policy.json
  aws --region $REGION iam put-role-policy --role-name ecsRole --policy-name ecsRolePolicy --policy-document file:///tmp/role-policy.json
  aws --region $REGION iam create-instance-profile --instance-profile-name ecsRole
  aws --region $REGION iam add-role-to-instance-profile --instance-profile-name ecsRole --role-name ecsRole
  aws --region $REGION ec2 describe-security-groups
  SGID_RESP=$(aws --region $REGION ec2 create-security-group --group-name $CLUSTER_NAME --description $CLUSTER_NAME)
  GROUP_ID=$(perl -ne 'if (/"GroupId": "([^"]+)"/) { print $1; }' <<< $SGID_RESP)
  aws --region $REGION ec2 authorize-security-group-ingress --group-id $GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
  aws --region $REGION ec2 authorize-security-group-ingress --group-id $GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
  aws --region $REGION ecs create-cluster --cluster-name $CLUSTER_NAME
  aws --region $REGION ec2 run-instances --count $CLUSTER_SIZE --image-id $AMI_ID --instance-type $INSTANCE_TYPE --key-name $KEY_PAIR --iam-instance-profile Name=ecsRole --security-group-id $GROUP_ID --associate-public-ip-address --user-data file:///tmp/user-data.sh
fi

aws --region $REGION ecs register-task-definition --cli-input-json file:///tmp/task-definition.json
# we can only launch up to 10 tasks at a time
BATCHES=$((${NUM_WORKERS} / 10))
REMAINDER=$((${NUM_WORKERS} % 10))
for i in `seq $BATCHES`; do
  aws --region $REGION ecs run-task --cluster $CLUSTER_NAME --count 10 --task-definition ${CLUSTER_NAME}_${PROGRAM_ID}
  # sleep between calls to avoid throttling
  sleep 5
done
if (( $REMAINDER > 0 )); then
  aws --region $REGION ecs run-task --cluster $CLUSTER_NAME --count $REMAINDER --task-definition ${CLUSTER_NAME}_${PROGRAM_ID}
fi
