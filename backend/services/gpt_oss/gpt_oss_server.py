from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict, Any
import json
import re

app = FastAPI()


class ValidateRequest(BaseModel):
    messages: List[Dict[str, Any]]
    temperature: float = 0.0


def validate_mcqs(mcqs):
    """Add your actual validation logic here"""
    # For now, just return them as-is
    return mcqs


@app.post("/validate")
def validate_questions(req: ValidateRequest):
    """Dedicated validation endpoint"""
    if not req.messages:
        return {"content": json.dumps([])}

    prompt = req.messages[-1]["content"]
    print(
        f"[DEBUG] Received validation request with prompt: {prompt[:200]}..."
    )  # Debug log

    try:
        # The prompt looks like: "You are a quality control agent... Input MCQs: [{...}]"
        # We need to extract the JSON part

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
                    mcqs = json.loads(mcqs_json)
                else:
                    return {"content": json.dumps([])}

        # Method 2: General JSON extraction
        else:
            # Try to find JSON array or object in the entire prompt
            json_match = re.search(r"(\[.*\]|\{.*\})", prompt, re.DOTALL)
            if json_match:
                mcqs_json = json_match.group(1)
                mcqs = json.loads(mcqs_json)
            else:
                return {"content": json.dumps([])}

        # Validate the MCQs
        validated_mcqs = validate_mcqs(mcqs)

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
