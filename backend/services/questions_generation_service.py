import os
import json
import re
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
from langchain_core.output_parsers import JsonOutputParser
from langchain.schema import SystemMessage, HumanMessage
from .gpt_oss.gpt_oss_wrapper import GPTOSSWrapper

import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


# -----------------------------
# Load environment variables
# -----------------------------
load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found. Please set it in your .env file.")

# -----------------------------
# Initialize LLM
# -----------------------------
llm = ChatOpenAI(model="gpt-4o", temperature=0.2)
oss_llm = GPTOSSWrapper(endpoint_url="http://localhost:5001/validate", temperature=0.0)

# -----------------------------
# System Message
# -----------------------------
SYSTEM_MESSAGE = SystemMessage(
    content="""
You are an academic question generator for IT topics.
- Generate coding and non-coding questions based on given topics.
- Output valid JSON only.
- Include difficulty (Easy/Medium/Hard) and category (Coding/Non-coding).
- Use concise formal academic language.
- Do not include answers unless explicitly instructed.
- Coding questions must include short self-contained code snippets (≤30 lines). No external files or APIs.
"""
)

# -----------------------------
# JSON Parser
# -----------------------------
json_parser = JsonOutputParser()

# -----------------------------
# Prompt Templates
# -----------------------------
topics_prompt = PromptTemplate(
    input_variables=["user_input"],
    template="Extract all coding-related topics, skills, languages, libraries, and frameworks from: '{user_input}'. Output comma-separated list, no explanations.",
)

languages_prompt = PromptTemplate(
    input_variables=["topics"],
    template="From this list: '{topics}', extract all programming languages. Return comma-separated list or 'None' if none.",
)

coding_questions_prompt = PromptTemplate(
    input_variables=["topics", "lang", "count"],
    template="""Generate {count} coding problems based on: '{topics}' in '{lang}'.
- Present incomplete code, buggy code, or output prediction questions 
- Question types allowed: output prediction, identify the bug, complete the missing logic (no markdown blocks)  
- Code must not be a complete runnable program. It must contai a bug, missing lines, or a tricky behavior suitable for MCQs
- Difficulty ratio: 1 Easy, 1 Medium, 3 Hard (if {count} >=5; else distribute proportionally)
- Only self-contained examples, no APIs/external files
- Return as JSON array like:
[{{"question": "...", "code": "...", "language": "{lang}", "difficulty": "Easy/Medium/Hard", "category": "Coding"}}]""",
)

non_coding_questions_prompt = PromptTemplate(
    input_variables=["topics"],
    template="""Generate 5 non-coding conceptual questions based on: '{topics}'.
- Use formal academic language.
- Include definitions, theory, practical applications, higher-order thinking.
- Ensure all topics represented at least once.
- Difficulty ratio: 1 Easy, 1 Medium, 2 Hard.
- Return as JSON array like:
[{{"question": "...", "difficulty": "Easy/Medium/Hard", "category": "Non-coding"}}]""",
)

coding_mcqs_prompt = PromptTemplate(
    input_variables=["questions"],
    template="""Convert the following coding questions to JSON MCQs:
{questions}

Requirements:
- Keep difficulty/category unchanged
- Each question must have 4 equally difficult and plausible options: A, B, C, D
- Only 1 option correct, indicate with "answer"
- Options format: ["A. Option text", "B. Option text", "C. Option text", "D. Option text"]
- Preserve the 'code' and 'language' fields from original questions
- Return JSON only, no markdown code blocks, no explanations
- Structure: [{{"question": "...", "code": "...", "language": "...", "options": ["A...","B...","C...","D..."], "answer":"A", "difficulty":"Easy", "category":"Coding"}}]

IMPORTANT: Output must be valid JSON only, no ```json or any other text:""",
)

non_coding_mcqs_prompt = PromptTemplate(
    input_variables=["questions"],
    template="""Convert the following non-coding questions to JSON MCQs:
{questions}

Requirements:
- Keep difficulty/category unchanged
- Each question must have 4 equally difficult and plausible options: A, B, C, D
- Only 1 option correct, indicate with "answer"
- Options format: ["A. Option text", "B. Option text", "C. Option text", "D. Option text"]
- Return JSON only, no markdown code blocks, no explanations
- Structure: [{{"question": "...", "options": ["A...","B...","C...","D..."], "answer":"A", "difficulty":"Easy", "category":"Non-coding"}}]
""",
)

# create validation chain prompt
oss_validation_prompt = PromptTemplate(
    input_variables=["mcqs"],
    template="""
You are a quality control agent for multiple-choice questions.
- Check each question, options, and answer for correctness and consistency.
- Do not add new questions or answers.
- Return the same JSON structure with corrections if needed.
- If all questions are correct, return them unchanged.

Input MCQs: {mcqs}
""",
)

# -----------------------------
# LLM Chains
# -----------------------------
topics_chain = LLMChain(llm=llm, prompt=topics_prompt)
languages_chain = LLMChain(llm=llm, prompt=languages_prompt)
coding_questions_chain = LLMChain(
    llm=llm, prompt=coding_questions_prompt, output_parser=json_parser
)
non_coding_questions_chain = LLMChain(
    llm=llm, prompt=non_coding_questions_prompt, output_parser=json_parser
)
coding_mcqs_chain = LLMChain(llm=llm, prompt=coding_mcqs_prompt)
non_coding_mcqs_chain = LLMChain(llm=llm, prompt=non_coding_mcqs_prompt)
oss_validation_chain = LLMChain(llm=oss_llm, prompt=oss_validation_prompt)


def extract_json_from_response(text):
    """Extract JSON from LLM response that might be wrapped in markdown"""
    if isinstance(text, (dict, list)):
        return text

    if isinstance(text, str):
        # try to parse as pure JSON first
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass

        # extract JSON from markdown code blocks
        json_match = re.search(r"```(?:json)?\s*(.*?)\s*```", text, re.DOTALL)
        if json_match:
            json_str = json_match.group(1).strip()
            try:
                return json.loads(json_str)
            except json.JSONDecodeError:
                pass

        # try to find JSON array pattern
        array_match = re.search(r"(\[.*\])", text, re.DOTALL)
        if array_match:
            try:
                return json.loads(array_match.group(1))
            except json.JSONDecodeError:
                pass

    return None


def validate_question_structure(questions):
    """Validate that each question has the required structure"""
    valid_questions = []
    for q in questions:
        if not isinstance(q, dict):
            continue

        # for all questions, only require question, difficulty, category
        required_fields = ["question", "options", "answer", "difficulty", "category"]

        # check if basic fields exist
        if not all(key in q for key in required_fields):
            continue

        # if it's a coding question, check for code and language
        if q.get("category") == "Coding":
            if "code" not in q or "language" not in q:
                continue

        # validate options
        if "options" in q:
            if not (isinstance(q["options"], list) and len(q["options"]) == 4):
                continue

        # validate answer
        if "answer" in q:
            if q["answer"] not in ["A", "B", "C", "D"]:
                continue

        valid_questions.append(q)

    return valid_questions


def run_oss_validation(mcqs, chain):
    """Run OSS validation safely and fallback to original if OSS fails"""
    # flags hallucination/suggests corrections
    # this line sends the MCQs to the OSS agent for validation.
    # OSS checks for inconsistencies, hallucinations, or errors in options/answers
    try:
        # format the request properly for the server
        mcqs_json = json.dumps(mcqs)
        prompt_text = f"Validate these MCQs: {mcqs_json}"

        # send properly formatted request
        response = chain.run({"mcqs": prompt_text})
        validated = extract_json_from_response(response)

        if isinstance(validated, list) and validated:
            return validated
        print(
            "[OSS WARNING] Validation returned empty or invalid, using original MCQs."
        )
        return mcqs
    except Exception as e:
        print("[OSS ERROR] Exception during validation, using original MCQs:", e)
        return mcqs


def generate_questions(skill_reflection: str, thesis_findings: str, career_goals: str):
    user_input = f"Skill Reflection: {skill_reflection}\nThesis Findings: {thesis_findings}\nCareer Goals: {career_goals}"

    # extract topics
    topics = topics_chain.run({"user_input": user_input}).strip()
    print("\n[DEBUG] Extracted topics:", topics)

    # extract programming languages with filtering
    all_languages_text = languages_chain.run({"topics": topics}).strip()
    language_list = []
    if all_languages_text != "none":
        language_list = [lang.strip() for lang in all_languages_text.split(",")]
    print("[DEBUG] Filtered languages list:", language_list)

    # generate coding questions
    coding_questions = []
    total_coding_questions = 5
    if language_list:
        # merge all languages into one string for prompt
        langs_str = ", ".join(language_list)
        try:
            raw = coding_questions_chain.run(
                {"topics": topics, "lang": langs_str, "count": total_coding_questions}
            )

            parsed = extract_json_from_response(raw)
            if isinstance(parsed, list):
                coding_questions.extend(parsed)
                print(
                    f"[SUCCESS] Generated {len(coding_questions)} coding questions for {langs_str}"
                )

        except Exception as e:
            print(f"[ERROR] Failed coding questions for {langs_str}:", e)

    # generate non-coding questions
    try:
        non_coding_questions = non_coding_questions_chain.run({"topics": topics})
        if not isinstance(non_coding_questions, list):
            non_coding_questions = []
    except Exception as e:
        print("[ERROR] Failed non-coding questions:", e)
        non_coding_questions = []

    # convert coding questions to MCQs
    coding_mcqs = []
    if coding_questions:
        try:
            coding_mcqs_raw = coding_mcqs_chain.run({"questions": coding_questions})
            coding_mcqs = extract_json_from_response(coding_mcqs_raw)

            if not isinstance(coding_mcqs, list):
                print(f"[ERROR] Coding MCQs are not a list. Type: {type(coding_mcqs)}")
                coding_mcqs = []
            else:
                coding_mcqs = validate_question_structure(coding_mcqs)

        except Exception as e:
            print("[ERROR] Failed coding MCQs:", e)

    # convert non-coding questions to MCQs
    non_coding_mcqs = []
    if non_coding_questions:
        try:
            non_coding_mcqs_raw = non_coding_mcqs_chain.run(
                {"questions": non_coding_questions}
            )
            non_coding_mcqs = extract_json_from_response(non_coding_mcqs_raw)

            if not isinstance(non_coding_mcqs, list):
                non_coding_mcqs = []
            else:
                non_coding_mcqs = validate_question_structure(non_coding_mcqs)

        except Exception as e:
            print("[ERROR] Failed non-coding MCQs:", e)

    # validate coding MCQs
    if coding_mcqs:
        coding_mcqs = validate_question_structure(coding_mcqs)
        coding_mcqs = run_oss_validation(coding_mcqs, oss_validation_chain)

    # validate non-coding MCQs
    if non_coding_mcqs:
        non_coding_mcqs = validate_question_structure(non_coding_mcqs)
        non_coding_mcqs = run_oss_validation(non_coding_mcqs, oss_validation_chain)

    all_questions = coding_mcqs + non_coding_mcqs
    print("[DEBUG] Total questions generated:", len(all_questions))

    return {"questions": all_questions}
