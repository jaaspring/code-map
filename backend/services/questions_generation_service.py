import os
import json
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
You are an academic question generator for computer science topics.
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
{{"question": "...", "difficulty": "Easy/Medium/Hard", "category": "Non-coding"}}""",
)

coding_mcqs_prompt = PromptTemplate(
    input_variables=["questions"],
    template="""Convert the following coding questions to JSON MCQs:
{questions}
- Keep difficulty/category unchanged.
- Each question must have 4 options: A, B, C, D.
- Only 1 option correct, indicate with "answer".
- Options format example: "A. Option text"
- Return as JSON array like:
[{{"question": "...", "options": ["A","B","C","D"], "answer":"A", "difficulty":"Easy", "category":"Coding"}}]""",
)

non_coding_mcqs_prompt = PromptTemplate(
    input_variables=["questions"],
    template="""Convert the following non-coding questions to JSON MCQs:
{questions}
- Keep difficulty/category unchanged.
- Each question must have 4 options: A, B, C, D.
- Only 1 option correct, indicate with "answer".
- Options format example: "A. Option text"
- Return as JSON array like:
[{{"question": "...", "options": ["A","B","C","D"], "answer":"A", "difficulty":"Easy", "category":"Non-coding"}}]""",
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
coding_mcqs_chain = LLMChain(
    llm=llm, prompt=coding_mcqs_prompt, output_parser=json_parser
)
non_coding_mcqs_chain = LLMChain(
    llm=llm, prompt=non_coding_mcqs_prompt, output_parser=json_parser
)


def validate_and_fix_json(json_string):
    """Validate and fix JSON structure if possible"""
    try:
        # First try to parse as-is
        data = json.loads(json_string)
        return data
    except json.JSONDecodeError as e:
        print(f"[DEBUG] JSON parse error: {e}")
        print(f"[DEBUG] Problematic JSON: {json_string}")
        return None


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

    # Extract topics
    topics = topics_chain.run({"user_input": user_input}).strip()
    print("\n[DEBUG] Extracted topics:", topics)

    # Extract programming languages
    all_languages_text = languages_chain.run({"topics": topics}).strip()
    language_list = (
        []
        if all_languages_text.lower() == "none"
        else [lang.strip() for lang in all_languages_text.split(",")]
    )
    print("[DEBUG] Languages list:", language_list)

    # Generate coding questions
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

    # Generate non-coding questions
    try:
        non_coding_questions = non_coding_questions_chain.run({"topics": topics})
        if not isinstance(non_coding_questions, list):
            non_coding_questions = []
    except Exception as e:
        print("[ERROR] Failed non-coding questions:", e)
        non_coding_questions = []

    # Convert coding questions to MCQs
    coding_mcqs = []
    if coding_questions:
        try:
            coding_mcqs_raw = coding_mcqs_chain.run({"questions": coding_questions})
            coding_mcqs = (
                coding_mcqs_raw
                if isinstance(coding_mcqs_raw, list)
                else coding_mcqs_raw
            )
            if not isinstance(coding_mcqs, list):
                print("ERROR] Coding MCQs not a list")
                coding_mcqs = []
            else:
                # validate each question has the correct structure
                valid_questions = []
                for q in coding_mcqs:
                    if all(
                        key in q
                        for key in [
                            "question",
                            "options",
                            "answer",
                            "difficulty",
                            "category",
                        ]
                    ):
                        valid_questions.append(q)
                    else:
                        print(f"[WARNING] Skipping invalid question structure: {q}")
                coding_mcqs = valid_questions
        except Exception as e:
            print("[ERROR] Failed coding MCQs:", e)

    # Convert non-coding questions to MCQs
    non_coding_mcqs = []
    if non_coding_questions:
        try:
            non_coding_mcqs_raw = non_coding_mcqs_chain.run(
                {"questions": non_coding_questions}
            )
            non_coding_mcqs = (
                non_coding_mcqs_raw
                if isinstance(non_coding_mcqs_raw, list)
                else non_coding_mcqs_raw
            )
            if not isinstance(non_coding_mcqs, list):
                print("[ERROR] Non-coding MCQs are not a list")
                non_coding_mcqs = []
            else:
                # validate each question has the correct structure
                valid_questions = []
                for q in non_coding_mcqs:
                    if all(
                        key in q
                        for key in [
                            "question",
                            "options",
                            "answer",
                            "difficulty",
                            "category",
                        ]
                    ):
                        valid_questions.append(q)
                    else:
                        print(f"[WARNING] Skipping invalid question structure: {q}")
                non_coding_mcqs = valid_questions
        except Exception as e:
            print("[ERROR] Failed non-coding MCQs:", e)

    all_questions = coding_mcqs + non_coding_mcqs
    print("[DEBUG] Total questions generated:", len(all_questions))

    return {"questions": all_questions}
