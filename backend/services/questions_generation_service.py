import os
import json
import re
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
from langchain_core.output_parsers import JsonOutputParser
from langchain.schema import SystemMessage, HumanMessage

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
- Include code snippet (≤30 lines) and question about it.
- Embed code and question in JSON field "question".
- Difficulty ratio: 1 Easy, 1 Medium, 3 Hard (if {count} >=5; else distribute proportionally).
- Only self-contained examples, no APIs/external files.
- Return as JSON array like:
[{{"question": "<CODE HERE> What does this code output?", "difficulty": "Easy/Medium/Hard", "category": "Coding"}}]""",
)

non_coding_questions_prompt = PromptTemplate(
    input_variables=["topics"],
    template="""Generate 10 non-coding conceptual questions based on: '{topics}'.
- Use formal academic language.
- Include definitions, theory, practical applications, higher-order thinking.
- Ensure all topics represented at least once.
- Difficulty ratio: 1 Easy, 3 Medium, 6 Hard.
- Return as JSON array like:
[{{"question": "...", "difficulty": "Easy/Medium/Hard", "category": "Non-coding"}}]""",
)

coding_mcqs_prompt = PromptTemplate(
    input_variables=["questions"],
    template="""Convert the following coding questions to JSON MCQs:
{questions}

Requirements:
- Keep difficulty/category unchanged
- Each question must have 4 options: A, B, C, D
- Only 1 option correct, indicate with "answer"
- Options format: ["A. Option text", "B. Option text", "C. Option text", "D. Option text"]
- Return JSON only, no markdown code blocks, no explanations
- Structure: [{{"question": "...", "options": ["A...","B...","C...","D..."], "answer":"A", "difficulty":"Easy", "category":"Coding"}}]

IMPORTANT: Output must be valid JSON only, no ```json or any other text:""",
)

non_coding_mcqs_prompt = PromptTemplate(
    input_variables=["questions"],
    template="""Convert the following non-coding questions to JSON MCQs:
{questions}

Requirements:
- Keep difficulty/category unchanged
- Each question must have 4 options: A, B, C, D
- Only 1 option correct, indicate with "answer"
- Options format: ["A. Option text", "B. Option text", "C. Option text", "D. Option text"]
- Return JSON only, no markdown code blocks, no explanations
- Structure: [{{"question": "...", "options": ["A...","B...","C...","D..."], "answer":"A", "difficulty":"Easy", "category":"Non-coding"}}]
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
# remove JsonOutputParser from MCQ chains since they return markdown-wrapped JSON
coding_mcqs_chain = LLMChain(llm=llm, prompt=coding_mcqs_prompt)
non_coding_mcqs_chain = LLMChain(llm=llm, prompt=non_coding_mcqs_prompt)


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
        if isinstance(q, dict) and all(
            key in q
            for key in ["question", "options", "answer", "difficulty", "category"]
        ):
            # validate options is a list with 4 elements
            if isinstance(q["options"], list) and len(q["options"]) == 4:
                valid_questions.append(q)
            else:
                print(
                    f"[WARNING] Skipping question with invalid options: {q.get('options')}"
                )
        else:
            missing_keys = [
                k
                for k in ["question", "options", "answer", "difficulty", "category"]
                if k not in q
            ]
            print(f"[WARNING] Skipping question missing keys {missing_keys}")
    return valid_questions


# -----------------------------
# OpenAI Call Helper
# -----------------------------
def call_openai(prompt: str, max_token=2000) -> str:
    response = llm(SYSTEM_MESSAGE | HumanMessage(content=prompt))
    return response.content.strip()


# -----------------------------
# Generate Questions Function
# -----------------------------
def generate_questions(skill_reflection: str, thesis_findings: str, career_goals: str):
    user_input = f"Skill Reflection: {skill_reflection}\nThesis Findings: {thesis_findings}\nCareer Goals: {career_goals}"

    # extract topics
    topics = topics_chain.run({"user_input": user_input}).strip()
    print("\n[DEBUG] Extracted topics:", topics)

    # extract programming languages
    all_languages_text = languages_chain.run({"topics": topics}).strip()
    language_list = (
        []
        if all_languages_text.lower() == "none"
        else [lang.strip() for lang in all_languages_text.split(",")]
    )
    print("[DEBUG] Languages list:", language_list)

    # generate coding questions
    coding_questions = []
    total_coding_questions = 5
    if language_list:
        num_languages = len(language_list)
        base_count = total_coding_questions // num_languages
        remainder = total_coding_questions % num_languages
        questions_per_language = {lang: base_count for lang in language_list}
        for i in range(remainder):
            questions_per_language[language_list[i]] += 1
        for lang, count in questions_per_language.items():
            if count == 0:
                continue
            try:
                coding_json = coding_questions_chain.run(
                    {"topics": topics, "lang": lang, "count": count}
                )
                if isinstance(coding_json, list):
                    coding_questions.extend(coding_json)
            except Exception as e:
                print(f"[ERROR] Failed coding questions for {lang}:", e)

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
                print(f"[DEBUG] Raw output: {coding_mcqs_raw}")
                coding_mcqs = []
            else:
                coding_mcqs = validate_question_structure(coding_mcqs)

        except Exception as e:
            print("[ERROR] Failed coding MCQs:", e)
            print(f"[DEBUG] Raw output: {coding_mcqs_raw}")

    # convert non-coding questions to MCQs
    non_coding_mcqs = []
    if non_coding_questions:
        try:
            non_coding_mcqs_raw = non_coding_mcqs_chain.run(
                {"questions": non_coding_questions}
            )
            non_coding_mcqs = extract_json_from_response(non_coding_mcqs_raw)

            if not isinstance(non_coding_mcqs, list):
                print(
                    f"[ERROR] Non-coding MCQs are not a list. Type: {type(non_coding_mcqs)}"
                )
                print(f"[DEBUG] Raw output: {non_coding_mcqs_raw}")
                non_coding_mcqs = []
            else:
                non_coding_mcqs = validate_question_structure(non_coding_mcqs)

        except Exception as e:
            print("[ERROR] Failed non-coding MCQs:", e)
            print(f"[DEBUG] Raw output: {non_coding_mcqs_raw}")

    all_questions = coding_mcqs + non_coding_mcqs
    print("[DEBUG] Total questions generated:", len(all_questions))

    return {"questions": all_questions}
