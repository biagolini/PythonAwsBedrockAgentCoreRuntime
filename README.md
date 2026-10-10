# AWS Bedrock AgentCore Runtime

**Author:** Carlos Biagolini-Jr.

**LinkedIn:** [https://www.linkedin.com/in/biagolini/](https://www.linkedin.com/in/biagolini/)

**Medium:** [https://medium.com/@biagolini](https://medium.com/@biagolini)

## Overview

This project demonstrates how to deploy a custom AI agent on [Amazon Bedrock AgentCore Runtime](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agents-tools-runtime.html) using a Docker container (ARM64). The agent implements the AgentCore Runtime contract (`/invocations` POST and `/ping` GET endpoints) using FastAPI and the Amazon Bedrock Converse API.

## Architecture

The setup provisions:

- **ECR Repository** to store the agent container image
- **AgentCore Runtime** that pulls the image and runs the agent in isolated microVMs

The agent uses Amazon Nova Lite as the foundation model and acts as a sales assistant for a used car dealership. It responds to customer queries using its general knowledge and a system prompt.

## Prerequisites

- AWS account with credentials configured
- Docker with buildx support (for ARM64 cross-compilation)
- AWS CLI configured
- AWS Region where AgentCore is available (e.g., us-east-1, us-west-2)
- Access to Amazon Nova Lite model in Amazon Bedrock

## Setup

1. Clone this repository:

```bash
git clone https://github.com/biagolini/PythonAwsBedrockAgentCoreRuntime.git
cd PythonAwsBedrockAgentCoreRuntime
```

2. Set your environment variables:

```bash
export AWS_PROFILE=<your-aws-profile>  # optional, if you use named profiles
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=<your-account-id>
export ECR_REPO=agentcore/car-agent-runtime
export REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
export REPO_URI="${REGISTRY}/${ECR_REPO}"
```

3. Create the ECR repository:

```bash
aws ecr create-repository --repository-name ${ECR_REPO} --region ${AWS_REGION}
```

4. Build the ARM64 image:

Make sure the Docker daemon is running first. You can check with:

```bash
docker info
```

If it returns an error like `Cannot connect to the Docker daemon`, start Docker (on macOS, open Docker Desktop or run `open -a Docker`; on Linux, `sudo systemctl start docker`) and wait a few seconds. Then build:

```bash
docker buildx build --platform linux/arm64 -t ${ECR_REPO}:latest --load .
```

5. Authenticate Docker with ECR:

```bash
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $REGISTRY
```

6. Tag and push to ECR:

```bash
docker tag ${ECR_REPO}:latest ${REPO_URI}:latest
docker push ${REPO_URI}:latest
```

> **Optional:** steps 4 to 6 (build, authenticate, tag, and push) are also wrapped in a helper script, if you prefer a single command. The repository must already exist (step 3); the script does not create it. The ECR repository name is set at the top of the script (`ECR_REPO`). The script also checks that the Docker daemon is running and tries to start it if it is not (Docker Desktop on macOS, `systemctl` on Linux).
>
> ```bash
> AWS_PROFILE=<your-aws-profile> ./scripts/build_and_push.sh
> ```

## Usage

After pushing the image to ECR, create the AgentCore Runtime via the AWS Console:

1. Navigate to **Amazon Bedrock AgentCore > Runtime > Create runtime**
2. Set the source type to **ECR Container** and provide the Image URI: `${REPO_URI}:latest`
3. Wait for the status to become **Ready**
4. Invoke the agent using the AWS CLI:

```bash
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn "arn:aws:bedrock-agentcore:${AWS_REGION}:${AWS_ACCOUNT_ID}:runtime/<your-runtime-id>" \
  --runtime-session-id "test-session-00000000000000000000001" \
  --qualifier "DEFAULT" \
  --payload $(echo '{"prompt": "Hi, do you have any SUVs available?"}' | base64) \
  /dev/stdout
```

For detailed step-by-step instructions, see the companion article on Medium.

## Cleanup

1. Delete the AgentCore Runtime in the AWS Console
2. Delete the ECR repository:

```bash
aws ecr delete-repository --repository-name ${ECR_REPO} --region ${AWS_REGION} --force
```

## Project Structure

```
.
├── agent.py            # FastAPI application with /invocations and /ping endpoints
├── Dockerfile          # ARM64 container configuration
├── requirements.txt    # Python dependencies (fastapi, uvicorn, boto3)
├── scripts/
│   └── build_and_push.sh  # Optional: build and push the image to an existing ECR repo
└── README.md
```

## Contributing

Feel free to submit issues and pull requests.

## License

This project is open source and available under the [MIT License](LICENSE).
