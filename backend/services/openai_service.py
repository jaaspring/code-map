import os
import json
import openai
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
from langchain_core.output_parsers import JsonOutputParser


# Load environment variables
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found. Please set it in your .env file.")

# Initialize OpenAI client
client = openai.OpenAI(api_key=OPENAI_API_KEY)

llm = ChatOpenAI(model="gpt-4o", temperature=0.2)

# PromptTemplate for extracting topics
topics_prompt = PromptTemplate(
    input_variables=["user_input"],
    template="""Extract all **coding-related** topics, skills, languages, libraries, and frameworks 
from this statement: '{user_input}'.
Output them as a single comma-separated list. No numbering, no explanations, no extra words.""",
)

topics_chain = LLMChain(llm=llm, prompt=topics_prompt)

# PromptTemplate for extracting programming languages
languages_prompt = PromptTemplate(
    input_variables=["topics"],
    template="""From the following list of topics: '{topics}', extract all programming languages mentioned.
Return a comma-separated list. If none are found, return 'None'.""",
)

languages_chain = LLMChain(llm=llm, prompt=languages_prompt)

# PromptTemplate for generating coding questions
coding_questions_prompt = PromptTemplate(
    input_variables=["topics", "lang", "count"],
    template="""Generate exactly {count} coding problems based on: '{topics}'.
    - Include a short code snippet in '{lang}' (≤30 lines).
    - Then write a question about that snippet.
    - Embed BOTH the code and the question text in the JSON field "question".
    - Difficulty ratio: 1 Easy, 1 Medium, 3 Hard (if {count} >=5, otherwise distribute proportionally).
    - Format each question as code (triple backticks) + text.
    - Only self-contained examples, no APIs or external files.
    - Use formal academic language appropriate for undergraduate or graduate students.
    - Do NOT include answers.
    - Return your output as a JSON array like this:
        [
        {{
            "question": "```<CODE HERE>``` What does this code output?",
            "difficulty": "Easy/Medium/Hard",
            "category": "Coding"
        }}
        ]
    """,
)

coding_questions_chain = LLMChain(llm=llm, prompt=coding_questions_prompt)

# PromptTemplate for generating non-coding questions
non_coding_questions_prompt = PromptTemplate(
    input_variables=["topics"],
    template="""Generate exactly 10 non-coding conceptual questions based on: '{topics}'.
    - No coding required.
    - Use formal academic language suitable for college-level students.
    - Cover definitions, theoretical concepts, practical applications, and real-world examples.
    - Include higher-order thinking questions (analysis, synthesis, evaluation), not just memorization.
    - Ensure all topics are represented at least once.
    - Difficulty ratio: 1 Easy, 3 Medium, 6 Hard.
    - Return questions as JSON list, each object with:
      {{"question": "...", "difficulty": "Easy/Medium/Hard", "category": "Non-coding"}}""",
)

non_coding_questions_chain = LLMChain(llm=llm, prompt=non_coding_questions_prompt)

# PromptTemplate for coding MCQs
coding_mcqs_prompt = PromptTemplate(
    input_variables=["questions"],
    template="""Convert the following coding questions into JSON multiple-choice questions (MCQs):
{questions}

Strict rules:
- Return only valid JSON, no explanation or extra text.
- Keep difficulty and category unchanged.
- Each question must have exactly 4 options labeled "A", "B", "C", "D".
- Only 1 option is correct; indicate it with "answer": "A"/"B"/"C"/"D".
- Options format example: "A. Option text"
- JSON format MUST be an array of objects like:
[
  {{"question": "...", "options": ["A","B","C","D"], "answer":"A", "difficulty":"Easy", "category":"Coding"}}
]""",
)

coding_mcqs_chain = LLMChain(llm=llm, prompt=coding_mcqs_prompt)


# PromptTemplate for non-coding MCQs
non_coding_mcqs_prompt = PromptTemplate(
    input_variables=["questions"],
    template="""Convert the following non-coding questions into JSON multiple-choice questions (MCQs):
{questions}

Strict rules:
- Return only valid JSON, no explanation or extra text.
- Keep difficulty and category unchanged.
- Each question must have exactly 4 options labeled "A", "B", "C", "D".
- Only 1 option is correct; indicate it with "answer": "A"/"B"/"C"/"D".
- Options format example: "A. Option text"
- JSON format MUST be an array of objects like:
[
  {{"question": "...", "options": ["A","B","C","D"], "answer":"A", "difficulty":"Easy", "category":"Non-coding"}}
]""",
)

non_coding_mcqs_chain = LLMChain(llm=llm, prompt=non_coding_mcqs_prompt)

# Parser
json_parser = JsonOutputParser()

coding_questions_chain = LLMChain(
    llm=llm,
    prompt=coding_questions_prompt,
    output_parser=json_parser,
)

non_coding_questions_chain = LLMChain(
    llm=llm,
    prompt=non_coding_questions_prompt,
    output_parser=json_parser,
)

coding_mcqs_chain = LLMChain(
    llm=llm,
    prompt=coding_mcqs_prompt,
    output_parser=json_parser,
)

non_coding_mcqs_chain = LLMChain(
    llm=llm,
    prompt=non_coding_mcqs_prompt,
    output_parser=json_parser,
)


def call_openai(prompt: str, max_token=2000) -> str:
    """Send a prompt to OpenAI via langchain."""
    response = llm.invoke(prompt)
    return response.content.strip()


def generate_questions(user_input: str):
    # Extract topics
    topics = topics_chain.run({"user_input": user_input}).strip()
    print("\n[DEBUG] Extracted topics:", topics)

    # Extract programming languages
    all_languages_text = languages_chain.run({"topics": topics}).strip()
    if all_languages_text.lower() == "none":
        language_list = []
    else:
        language_list = [lang.strip() for lang in all_languages_text.split(",")]
    print("[DEBUG] Languages list:", language_list)

    # Generate coding questions
    coding_questions = []
    total_coding_questions = 5

    if language_list:
        # Determine distribution per language
        num_languages = len(language_list)
        base_count = total_coding_questions // num_languages
        remainder = total_coding_questions % num_languages

        questions_per_language = {lang: base_count for lang in language_list}
        for i in range(remainder):
            questions_per_language[language_list[i]] += 1

        # Generate coding questions per language
        for lang, count in questions_per_language.items():
            if count == 0:
                continue
            try:
                coding_json = coding_questions_chain.run(
                    {"topics": topics, "lang": lang, "count": count}
                )
                # JSON parser already returns list of dicts
                if isinstance(coding_json, list):
                    coding_questions.extend(coding_json)
            except Exception as e:
                print(f"[ERROR] Failed to parse coding questions for {lang}:", e)

    # Generate non-coding questions
    try:
        non_coding_questions = non_coding_questions_chain.run({"topics": topics})
        if not isinstance(non_coding_questions, list):
            non_coding_questions = []
    except Exception as e:
        print("[ERROR] Failed to parse non-coding questions:", e)
        non_coding_questions = []

    # Convert coding questions to MCQs
    coding_mcqs = []
    if coding_questions:
        try:
            coding_mcqs_raw = coding_mcqs_chain.run({"questions": coding_questions})
            coding_mcqs = coding_mcqs_raw if isinstance(coding_mcqs_raw, list) else []
        except Exception as e:
            print("[ERROR] Failed to parse coding MCQs:", e)
            coding_mcqs = []

    # Convert non-coding questions to MCQs
    non_coding_mcqs = []
    if non_coding_questions:
        try:
            non_coding_mcqs_raw = non_coding_mcqs_chain.run(
                {"questions": non_coding_questions}
            )
            non_coding_mcqs = (
                non_coding_mcqs_raw if isinstance(non_coding_mcqs_raw, list) else []
            )
        except Exception as e:
            print("[ERROR] Failed to parse non-coding MCQs:", e)
            non_coding_mcqs = []

    # Merge all questions
    all_questions = coding_mcqs + non_coding_mcqs
    print("[DEBUG] Total questions generated:", len(all_questions))

    return {
        "questions": all_questions,
    }
