from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import boto3
import os

app = FastAPI(title="Car Agent Server", version="1.0.0")

SYSTEM_PROMPT = """You are a helpful sales assistant for a used car dealership. \
You help customers find vehicles that match their needs and budget. \
Be friendly, knowledgeable, and transparent about vehicle conditions. \
If you don't have specific inventory data, let the customer know \
you'll check and get back to them."""

REGION = os.environ.get("AWS_REGION", "us-east-1")
MODEL_ID = os.environ.get("MODEL_ID", "us.amazon.nova-lite-v1:0")

bedrock = boto3.client("bedrock-runtime", region_name=REGION)


class InvocationRequest(BaseModel):
    prompt: str


class InvocationResponse(BaseModel):
    response: str
    status: str


@app.post("/invocations", response_model=InvocationResponse)
async def invoke_agent(request: InvocationRequest):
    try:
        response = bedrock.converse(
            modelId=MODEL_ID,
            messages=[{"role": "user", "content": [{"text": request.prompt}]}],
            system=[{"text": SYSTEM_PROMPT}],
        )

        assistant_message = response["output"]["message"]["content"][0]["text"]

        return InvocationResponse(
            response=assistant_message,
            status="success",
        )

    except bedrock.exceptions.ClientError as e:
        raise HTTPException(status_code=500, detail=f"Bedrock error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Agent processing failed: {str(e)}")


@app.get("/ping")
async def ping():
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8080)
