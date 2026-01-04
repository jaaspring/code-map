from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict, Any
import json
import re
from contextlib import asynccontextmanager
from .anthropic_client import validate_with_model, load_model, check_model_status, generate_response

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load Claude client on startup
    print("[Claude Agent] Server starting, initializing API client...")
    load_model()
    yield
    print("[Claude Agent] Server shutting down.")

app = FastAPI(lifespan=lifespan)


class ValidateRequest(BaseModel):
    messages: List[Dict[str, Any]]
    temperature: float = 0.0


@app.get("/health")
def health_check():
    """Checks if the local model is loaded and ready."""
    is_ready = check_model_status()
    status = "healthy" if is_ready else "loading"
    return {
        "status": status,
        "model_loaded": is_ready
    }


@app.post("/validate")
def validate_questions(req: ValidateRequest):
    """Dedicated validation endpoint"""
    if not req.messages:
        return {"content": json.dumps([])}

    prompt = req.messages[-1]["content"]
    print(
        f"[DEBUG] Received validation request with prompt: {prompt[:200]}..."
    )  # Debug log

    # Relaxed check: Let validate_with_model handle lazy loading if needed
    if not check_model_status():
        print("[GPT OSS INFO] Model not fully loaded yet, triggering lazy load...")

    try:
        # The prompt looks like: "You are a quality control agent... Input MCQs: [{...}]"
        # We need to extract the JSON part
        mcqs = []

        # Method 1: Look for "Input MCQs:" in the prompt
        if "Input MCQs:" in prompt:
            # Split at "Input MCQs:" and take the second part
            mcqs_part = prompt.split("Input MCQs:", 1)[1].strip()

            # Try to parse directly
            try:
                mcqs = json.loads(mcqs_part)
            except json.JSONDecodeError:
                # Try to extract JSON using regex
                json_match = re.search(r"(\[.*\]|\{.*\})", mcqs_part, re.DOTALL)
                if json_match:
                    mcqs_json = json_match.group(1)
                    try:
                        mcqs = json.loads(mcqs_json)
                    except:
                        pass
        
        # Method 2: General JSON extraction if Method 1 extraction failed or didn't yield list
        if not mcqs:
            # Try to find JSON array or object in the entire prompt
            json_match = re.search(r"(\[.*\])", prompt, re.DOTALL)
            if json_match:
                mcqs_json = json_match.group(1)
                try:
                    mcqs = json.loads(mcqs_json)
                except:
                    pass

        if not mcqs:
            print("[WARN] Could not extract MCQs from prompt.")
            return {"content": json.dumps([])}

        # Validate with local model
        validated_mcqs = validate_with_model(mcqs)

        # Return as JSON string
        return {"content": json.dumps(validated_mcqs)}

    except Exception as e:
        print(f"[ERROR] Validation failed: {e}")
        return {"content": json.dumps({"error": str(e)})}


# Keep the root endpoint for backward compatibility
class GenerateRequest(BaseModel):
    messages: list
    temperature: float = 0.0


@app.post("/")
def generate(req: GenerateRequest):
    """General generation endpoint"""
    prompt = req.messages[-1]["content"]
    return {"content": f"[GPT-OSS placeholder] {prompt}"}


class ChatRequest(BaseModel):
    messages: List[Dict[str, Any]]
    temperature: float = 0.0

@app.post("/chat")
def chat_endpoint(req: ChatRequest):
    """Generic chat endpoint for Claude"""
    if not req.messages:
        return {"content": ""}
    
    prompt = req.messages[-1]["content"]
    print(f"[Claude Agent] Chat request: {prompt[:50]}...")
    
    response_text = generate_response(prompt, temperature=req.temperature)
    return {"content": response_text}