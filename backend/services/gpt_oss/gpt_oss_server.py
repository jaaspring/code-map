from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()


class GenerateRequest(BaseModel):
    messages: list
    temperature: float = 0.0


@app.post("/")
def generate(req: GenerateRequest):
    prompt = req.messages[-1]["content"]

    result_content = f"[GPT-OSS placeholder] {prompt}"

    return {"content": result_content}
