import os
import json
import re
from typing import List, Dict, Any
from anthropic import Anthropic
from dotenv import load_dotenv

# Load environment variables (to get CLAUDE_API_KEY)
load_dotenv()

# Global client
_client = None
_model_name = "claude-opus-4-5-20251101"

def load_model():
    """
    Initializes the Anthropic client.
    """
    global _client
    if _client is not None:
        return

    print(f"[Claude Agent] Initializing Anthropic API client for {_model_name}...")
    api_key = os.getenv("CLAUDE_API_KEY")
    # Fallback: check if user put it in current env
    if not api_key:
         api_key = os.environ.get("CLAUDE_API_KEY")

    if not api_key:
        print("[Claude Agent ERROR] CLAUDE_API_KEY not found in environment variables.")
        return

    try:
        _client = Anthropic(api_key=api_key)
        print("[Claude Agent] Anthropic client initialized successfully.")
    except Exception as e:
        print(f"[Claude Agent ERROR] Failed to initialize Anthropic client: {e}")
        raise e

def validate_with_model(mcqs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Validates MCQs using the Anthropic API.
    """
    global _client
    if _client is None:
        print("[Claude Agent WARNING] Client not initialized, attempting to load now...")
        load_model()
        if _client is None:
             print("[Claude Agent ERROR] Cannot validate, client failed to initialize.")
             return mcqs
    
    print(f"[Claude Agent] Validating {len(mcqs)} questions with {_model_name}...")
    
    system_instruction = (
        "You are an expert Computer Science exam editor. "
        "Check the provided MCQs for errors in options/answers.\n"
        "If a question is correct, keep it exactly as is.\n"
        "If there is an error, FIX IT in the output JSON.\n"
        "Output ONLY a valid JSON array of the corrected MCQs.\n"
        "Do not include any explanations or markdown."
    )
    
    user_input = f"Here are the MCQs to validate:\n{json.dumps(mcqs, indent=2)}\n\nRespond with the JSON array only."
    
    try:
        message = _client.messages.create(
            model=_model_name,
            max_tokens=4096,
            temperature=0.0,
            system=system_instruction,
            messages=[
                {"role": "user", "content": user_input}
            ]
        )
        
        content = message.content[0].text
        
        # Helper to parse JSON
        def robust_parse(text):
            match = re.search(r"(\[.*\])", text, re.DOTALL)
            if not match:
                return None
            candidate = match.group(1)
            try:
                return json.loads(candidate)
            except:
                return None

        corrected_mcqs = robust_parse(content)
        
        if corrected_mcqs and isinstance(corrected_mcqs, list):
            if len(corrected_mcqs) != len(mcqs):
                print(f"[Claude Agent WARNING] API returned {len(corrected_mcqs)} questions, expected {len(mcqs)}. Discarding changes.")
                return mcqs
                
            print(f"[Claude Agent] Claude API returned {len(corrected_mcqs)} validated questions.")
            return corrected_mcqs
        else:
            print("[Claude Agent ERROR] Could not find valid JSON array in API response.")
            return mcqs

    except Exception as e:
        print(f"[Claude Agent ERROR] API validation error: {e}")
        return mcqs

def generate_response(prompt: str, temperature: float = 0.0) -> str:
    """
    Sends a generic prompt to Claude and returns the text response.
    """
    global _client
    if _client is None:
        load_model()
        if _client is None:
             return "[Claude Agent ERROR] Client failed to initialize."
    
    try:
        message = _client.messages.create(
            model=_model_name,
            max_tokens=4096,
            temperature=temperature,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )
        return message.content[0].text
    except Exception as e:
        return f"[Claude Agent ERROR] Generation error: {e}"

def check_model_status() -> bool:
    """Returns True if client is initialized."""
    return _client is not None
