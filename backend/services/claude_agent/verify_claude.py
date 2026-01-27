
import requests
import json
import time

def test_oss_validation():
    # Mock MCQs with an intentional error
    # Question 1: Answer is A, but options only have B, C, D (wait, usually A is first). 
    # Let's make an obvious error: Answer is "E" which doesn't exist.
    bad_mcqs = [
        {
            "question": "What is 2 + 2?",
            "options": ["A. 3", "B. 4", "C. 5", "D. 6"],
            "answer": "E",  # Invalid answer
            "difficulty": "Easy",
            "category": "Non-coding"
        }
    ]

    print(f"[Claude Agent] Validating {len(bad_mcqs)} questions...")

    prompt = f"You are a quality control agent... Input MCQs: {json.dumps(bad_mcqs)}"

    print("Checking Claude Agent status...")
    try:
        # Check health first
        health_res = requests.get("http://127.0.0.1:5001/health")
        health_data = health_res.json()

        if not health_data.get("model_loaded"):
             print("\n[WARN] Claude Client is connecting. This might take a moment on first run...")
             # Wait a bit?
             time.sleep(5)
             # Retry once
             health_res = requests.get("http://127.0.0.1:5001/health")
             if not health_res.json().get("model_loaded"):
                 print("[FATAL] Model failed to load. Check server logs.")
                 return
        
        print("[INFO] Model is loaded and ready.")

    except Exception as e:
         print(f"[FATAL] Could not connect to OSS Server at port 5001: {e}")
         return

    print("Sending request to Claude Agent server...")
    try:
        # Replaced direct import with HTTP request to avoid dependency on deleted module
        payload = {"messages": [{"role": "user", "content": prompt}]}
        response = requests.post("http://127.0.0.1:5001/validate", json=payload)
        
        if response.status_code != 200:
             print(f"FAILURE: Server returned {response.status_code} {response.text}")
             return

        content_str = response.json().get("content")
        content = json.loads(content_str)
        print("\nOriginal:", json.dumps(bad_mcqs, indent=2))
        print("\nValidated Raw Response:", json.dumps(content, indent=2))
        
        if content and isinstance(content, list) and len(content) > 0:
            ans = content[0].get("answer")
            print(f"\nFinal Answer: {ans}")
            if ans == "B":
                 print("SUCCESS: Answer corrected to B.")
            else:
                 print(f"FAILURE: Answer is {ans}, expected B.")
        else:
            print("FAILURE: Validation returned empty or invalid.")

    except Exception as e:
        print(f"Test failed: {e}")

if __name__ == "__main__":
    test_oss_validation()
