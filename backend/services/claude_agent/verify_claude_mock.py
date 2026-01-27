import json
import unittest
from unittest.mock import patch, MagicMock
from backend.services.claude_agent.claude_service import validate_questions, ValidateRequest

class TestClaudeLogic(unittest.TestCase):
    
    @patch('backend.services.claude_agent.anthropic_client._client')
    def test_correction_logic(self, mock_client):
        # Setup mock response object structure: message.content[0].text
        corrected_mcqs = [
            {
                "question": "What is 2 + 2?",
                "options": ["A. 3", "B. 4", "C. 5", "D. 6"],
                "answer": "B", 
                "difficulty": "Easy",
                "category": "Non-coding"
            }
        ]
        
        # Configure mock return structure for Anthropic API
        mock_message = MagicMock()
        mock_content_block = MagicMock()
        mock_content_block.text = json.dumps(corrected_mcqs)
        mock_message.content = [mock_content_block]
        
        # Configure the mock client.messages.create()
        mock_client.messages.create.return_value = mock_message
        
        # Input with error
        bad_mcqs = [
            {
                "question": "What is 2 + 2?",
                "options": ["A. 3", "B. 4", "C. 5", "D. 6"],
                "answer": "E", 
                "difficulty": "Easy",
                "category": "Non-coding"
            }
        ]
        prompt = f"Input MCQs: {json.dumps(bad_mcqs)}"
        req = ValidateRequest(messages=[{"role": "user", "content": prompt}])
        
        # Run
        print("Running mock validation...")
        
        # We also need to patch check_model_status to ensure it doesn't try to load the real client
        with patch('backend.services.claude_agent.anthropic_client.check_model_status', return_value=True):
             response = validate_questions(req)
        
        # Check
        content = json.loads(response["content"])
        print("Validated Output:", json.dumps(content, indent=2))
        
        self.assertEqual(len(content), 1)
        self.assertEqual(content[0]["answer"], "B")
        print("SUCCESS: Logic correctly processed the mocked Claude response.")

if __name__ == "__main__":
    unittest.main()
