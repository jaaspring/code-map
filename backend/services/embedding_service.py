import os
import re
import json
from typing import Any, Dict, List
from dotenv import load_dotenv
import openai
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import core.model_loader as loader
from core.database import db
from schemas.assessment import UserResponses
from services.scoring_service import calculate_score
from models.firestore_models import (
    get_follow_up_answers_by_user,
    get_generated_questions,
    add_user_skills,
)

# -----------------------------
# Env & OpenAI client
# -----------------------------
load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found. Please set it in your .env file.")

client = openai.OpenAI(api_key=OPENAI_API_KEY)


# -----------------------------
# OpenAI call function
# -----------------------------
def call_openai(prompt: str, max_tokens=2000, temperature=0.2) -> str:
    """
    Generate a descriptive profile text from OpenAI based on a prompt.
    """
    resp = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "system",
                "content": (
                    "You are an assistant that returns clean, concise outputs. "
                    "Write in a professional, neutral tone; avoid buzzwords."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        max_tokens=max_tokens,
        temperature=temperature,
    )
    return resp.choices[0].message.content.strip()


def normalize_option(opt: str) -> str:
    if not opt:
        return ""
    match = re.match(r"([A-Z])", opt.strip().upper())
    return match.group(1) if match else opt.strip().upper()


# -----------------------------
# Data aggregation for a user
# -----------------------------
def get_user_embedding_data(user_test_id: str) -> Dict[str, Any]:
    """
    Fetch user responses and follow-up results, compute score, build combined_data.
    score reflects how consistent/true the skillReflection is relative to follow-up answers.
    """
    # Fetch Firestore doc (dict)
    doc_ref = db.collection("user_tests").document(user_test_id).get()
    if not doc_ref.exists:
        return {"error": f"No user responses found for {user_test_id}"}

    doc = doc_ref.to_dict()

    try:
        # Convert dict → Pydantic model
        user_res = UserResponses(**doc)

        # Fetch all data once
        follow_ups = get_follow_up_answers_by_user(user_test_id)
        user_questions = get_generated_questions(user_test_id)

        # Build lookup table for O(1) question match
        question_lookup = {q["id"]: q for q in user_questions}

        # Build results for scoring
        results: List[Dict[str, Any]] = []
        for f in follow_ups:
            question_id = f["question_id"]
            correct_q_data = question_lookup.get(question_id)

            is_correct = bool(
                correct_q_data
                and normalize_option(correct_q_data.get("answer"))
                == normalize_option(f["selected_option"])
            )

            results.append(
                {
                    "question_id": question_id,
                    "question_text": (
                        correct_q_data.get("question_text") if correct_q_data else None
                    ),
                    "selected_option": f["selected_option"],
                    "correct_answer": (
                        correct_q_data.get("answer") if correct_q_data else None
                    ),
                    "is_correct": is_correct,
                }
            )

        # Calculate score (how true the skill reflection is)
        score_result = calculate_score(results)

        # Normalize programmingLanguages to a list (in case stored as JSON/text)
        prog_langs = user_res.programmingLanguages
        if isinstance(prog_langs, str):
            prog_langs = [p.strip() for p in prog_langs.split(",") if p.strip()]

        # Build combined data
        combined_data = {
            "user_test_id": user_test_id,
            "user_responses": {
                "educationLevel": user_res.educationLevel,
                "cgpa": user_res.cgpa,
                "thesisTopic": user_res.thesisTopic,
                "major": user_res.major,
                "programmingLanguages": prog_langs,
                "courseworkExperience": user_res.courseworkExperience,
                "skillReflection": user_res.skillReflection,
                "thesisFindings": user_res.thesisFindings,
                "careerGoals": user_res.careerGoals,
            },
            "follow_up_results": results,
            "score": score_result["score_percentage"],
        }
        return combined_data

    except Exception as e:
        # In case Firestore doc has unexpected fields/types
        return {"error": f"Failed to parse user responses: {str(e)}"}


# -----------------------------
# Analyze user skills & knowledge
# -----------------------------
def analyze_user_skills_knowledge(user_test_id: str) -> Dict[str, Any]:
    combined_data = get_user_embedding_data(user_test_id)
    if "error" in combined_data:
        return combined_data

    prompt = f"""
    Analyze the following student's data.

    INPUT DATA:
    {combined_data}

    TASK:
    1. Extract **technical skills** from: skillReflection, programmingLanguages, follow_up_results.
    2. Extract **knowledge areas** from: courseworkExperience, follow_up_results, thesisTopic, thesisFindings.
    3. Assign a level (Basic, Intermediate, Advanced) to each skill/knowledge based on:
        - Frequency and emphasis in answers
        - Evidence from follow-up results
        - Depth implied in projects or coursework
    4. Be specific: e.g., "Python with Django" → "Python", "Django".
    5. Include implied or contextual items, remove duplicates, keep the most specific term.

    OUTPUT:
    Return ONLY valid JSON with two keys:
    {{
        "skills": {{"Python": "Basic", "Communication": "Intermediate"}},
        "knowledge": {{"Algorithms": "Basic", "Database Systems": "Basic"}}
    }}
    No markdown, comments, or extra text.
    """

    try:
        response = call_openai(prompt, max_tokens=500, temperature=0.2)
        cleaned_response = response.strip()

        # Remove code block markers if present
        if cleaned_response.startswith("```json"):
            cleaned_response = cleaned_response[7:]
        elif cleaned_response.startswith("```"):
            cleaned_response = cleaned_response[3:]
        if cleaned_response.endswith("```"):
            cleaned_response = cleaned_response[:-3]
        cleaned_response = cleaned_response.strip()

        # Parse JSON
        result = json.loads(cleaned_response)

        # Store as JSON dicts
        skills_dict = result.get("skills", {})
        knowledge_dict = result.get("knowledge", {})

        try:
            add_user_skills(
                user_id=str(user_test_id), skills=skills_dict, knowledge=knowledge_dict
            )
            print(
                f"Saved skills/knowledge for user_test_id {user_test_id} to Firestore"
            )
            return {"skills": skills_dict, "knowledge": knowledge_dict}

        except Exception as e:
            error_msg = f"Failed to save skills/knowledge to Firestore: {e}"
            print(error_msg)
            return {"error": error_msg}

    except Exception as e:
        error_msg = f"Failed to analyze skills/knowledge: {str(e)}. Response: {cleaned_response if 'cleaned_response' in locals() else 'No response'}"
        print(error_msg)
        return {"error": error_msg}


# -----------------------------
# Profile generation via OpenAI
# -----------------------------
def _build_profile_prompt(combined_data: Dict[str, Any]) -> str:
    """
    Build a concise, evidence-based user profile for embedding.
    """
    return (
        "Write a concise, objective profile of the user based on the data below. "
        "Highlight technical skills, knowledge areas, strengths, weaknesses, and realistic next steps. "
        "Use 'score' to weigh how accurate the user's self-assessed skills are (higher = more accurate). "
        "Include only meaningful, evidence-based points. "
        "Return exactly one paragraph.\n\n"
        f"USER DATA:\n{combined_data}\n\n"
    )


def generate_user_profile_text(combined_data: Dict[str, Any]) -> str:
    prompt = _build_profile_prompt(combined_data)
    return call_openai(prompt)


# -----------------------------
# Create user embedding
# -----------------------------
def create_user_embedding(user_test_id: str) -> Dict[str, Any]:
    combined_data = get_user_embedding_data(user_test_id)
    if "error" in combined_data:
        return combined_data

    profile_text = generate_user_profile_text(combined_data)
    user_embedding = loader.get_embeddings(profile_text)

    return {
        "user_test_id": user_test_id,
        "profile_text": profile_text,  # the generated summary paragraph of the user
        "user_embedding": user_embedding,  # list[float], the vector representation for matching
        "combined_data": combined_data,  # included for debugging/inspection
    }


# -----------------------------
# Match user to job
# -----------------------------
def match_user_to_job(
    user_test_id: str,
    user_embedding: List[float],
    use_openai_summary: bool = True,
) -> Dict[str, Any]:
    """
    Compare user embedding to all job embeddings using cosine similarity.
    """
    # Check if globals are loaded correctly
    print(
        f"DF length: {len(loader.df)}, Job embeddings length: {len(loader.job_embeddings)}"
    )

    if loader.df.empty or not loader.job_embeddings:
        return {"error": "No jobs or embeddings available."}

    # Convert to numpy
    user_vec = np.array(user_embedding).reshape(1, -1)  # (1, dim)
    job_matrix = np.array(loader.job_embeddings)  # (num_jobs, dim)

    # Compute cosine similarity
    similarities = cosine_similarity(user_vec, job_matrix)[0]  # shape: (num_jobs,)

    # Get indices of top 3 jobs (sorted by similarity score)
    top_n = min(3, len(similarities))

    # Get sorted indices
    sorted_indices = np.argsort(similarities)[::-1]  # highest first

    # Deduplicate by job title before slicing
    seen_titles = set()
    unique_indices = []
    for idx in sorted_indices:
        title = loader.df.iloc[idx].get("Title", "N/A")
        if title not in seen_titles:
            seen_titles.add(title)
            unique_indices.append(idx)
        if len(unique_indices) >= top_n:
            break

    # Use unique_indices (deduplicated & limited to top_n)
    top_matches = []

    def clean_openai_json(raw_text: str) -> str:
        """Remove code blocks or extra whitespace from OpenAI response"""
        text = raw_text.strip()
        if text.startswith("```json"):
            text = text[7:]
        elif text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]
        return text.strip()

    def parse_json_response(response_text: str, response_type: str) -> Dict[str, str]:
        """Safely parse JSON response from OpenAI with error handling"""
        try:
            cleaned_text = clean_openai_json(response_text)
            print(f"Cleaned {response_type} response: {cleaned_text}")

            # Try to parse as JSON
            parsed_data = json.loads(cleaned_text)

            # Validate it's a dictionary
            if not isinstance(parsed_data, dict):
                print(f"Warning: {response_type} response is not a dictionary")
                return {}

            return parsed_data

        except json.JSONDecodeError as e:
            print(f"JSON decode error for {response_type}: {e}")
            print(f"Raw response: {response_text}")

            # Try to extract JSON from malformed response
            json_match = re.search(r"\{.*\}", response_text, re.DOTALL)
            if json_match:
                try:
                    extracted_json = json_match.group(0)
                    parsed_data = json.loads(extracted_json)
                    if isinstance(parsed_data, dict):
                        return parsed_data
                except:
                    pass

            return {}
        except Exception as e:
            print(f"Unexpected error parsing {response_type}: {e}")
            return {}

    for idx in unique_indices:
        job = loader.df.iloc[idx]
        similarity_score = float(similarities[idx])
        similarity_percentage = round(similarity_score * 100, 2)
        original_job_desc = job.get("Full Job Description", "N/A")

        # Initialize variables
        job_desc = original_job_desc
        required_skills = []
        required_knowledge = []

        # Generate cleaned/comprehensive description using OpenAI
        if use_openai_summary and original_job_desc != "N/A":
            try:
                summary_prompt = (
                    "Summarize the following job description in one concise, professional paragraph. "
                    "Focus on core responsibilities and tasks of the career. "
                    "Start with 'This career involves...'"
                    "Avoid mentioning overly detailed information such as the company, years of experience, etc."
                    "Keep it under 400 characters.\n\n"
                    f"JOB DESCRIPTION:\n{original_job_desc}\n\n"
                    "Return only the cleaned-up job description without any additional text."
                )

                skills_prompt = (
                    "ANALYZE THIS JOB DESCRIPTION AND EXTRACT ALL REQUIRED SKILLS WITH PROFICIENCY LEVELS:\n\n"
                    f"{original_job_desc}\n\n"
                    "DEFINITION:\n"
                    "- Skills are abilities or tools that a person can use to perform tasks.\n"
                    "- Examples of skills: programming languages, frameworks, libraries, software, platforms, or tools.\n"
                    "- Do NOT include theoretical knowledge, concepts, or methodologies.\n\n"
                    "EXTRACTION RULES:\n"
                    "1. Extract ONLY technical skills: programming languages, frameworks, libraries, tools, software, and platforms.\n"
                    "2. Assign a proficiency level for each skill: **ONLY** Basic, Intermediate, or Advanced.\n"
                    '3. Respond STRICTLY in JSON format as a dictionary: {"Skill Name": "Level", ...} without any additional text.\n'
                    "4. Be as specific as possible: if 'Python with Django' is mentioned, include 'Python' and 'Django' as separate entries.\n"
                    "5. Exclude soft skills and natural languages.\n"
                    "6. Include skills mentioned in requirements, qualifications, or responsibilities sections.\n"
                    "7. Remove duplicates and keep the most specific term.\n"
                    "8. If multiple skills are mentioned together, create separate entries for each.\n"
                    "9. DO NOT include explanations, markdown, or code blocks.\n\n"
                    "EXAMPLE OUTPUT:\n"
                    '{"Python": "Basic", "Django": "Intermediate", "SQL": "Advanced"}'
                )

                knowledge_prompt = (
                    "ANALYZE THIS JOB DESCRIPTION AND EXTRACT ALL REQUIRED KNOWLEDGE AREAS WITH PROFICIENCY LEVELS:\n\n"
                    f"{original_job_desc}\n\n"
                    "- Knowledge is the understanding of concepts, theories, methodologies, or domains.\n"
                    "- Examples of knowledge: Algorithms, Data Structures, Machine Learning, Web Development, Cybersecurity.\n"
                    "- Do NOT include specific tools, software, or platforms.\n\n"
                    "EXTRACTION RULES:\n"
                    "1. Extract ONLY knowledge domains, concepts, methodologies, and specialized areas.\n"
                    "2. Assign a proficiency level for each: **ONLY** Basic, Intermediate, or Advanced.\n"
                    '3. Respond STRICTLY in JSON format as a dictionary: {"Knowledge Name": "Level", ...}\n'
                    "4. Be as specific as possible: if 'Mathematics (Linear Algebra, Probability)' is mentioned, include 'Mathematics', 'Linear Algebra' and 'Probability' as separate entries.\n"
                    "5. Exclude soft skills and natural languages.\n"
                    "6. Remove duplicates and keep the most specific term.\n"
                    "7. If multiple knowledge areas are mentioned together, create separate entries.\n"
                    "8. DO NOT include explanations, markdown, or code blocks.\n\n"
                    "EXAMPLE OUTPUT:\n"
                    '{"Algorithms": "Basic", "Machine Learning": "Advanced", "Database Systems": "Intermediate"}'
                )

                print(f"Processing job {idx} with OpenAI...")

                # Get job description summary
                job_desc = call_openai(summary_prompt, max_tokens=400)
                print(f"Job description summary: {job_desc}")

                # Extract skills
                try:
                    skills_response = call_openai(skills_prompt, max_tokens=300)
                    print(f"Raw skills response: {skills_response}")

                    skills_data = parse_json_response(skills_response, "skills")
                    required_skills = skills_data
                    print(f"Parsed skills: {required_skills}")

                except Exception as skills_error:
                    print(f"Skills extraction failed for job {idx}: {skills_error}")
                    required_skills = ["Error extracting skills"]

                # Extract knowledge
                try:
                    knowledge_response = call_openai(knowledge_prompt, max_tokens=300)
                    print(f"Raw knowledge response: {knowledge_response}")

                    knowledge_data = parse_json_response(
                        knowledge_response, "knowledge"
                    )
                    required_knowledge = knowledge_data
                    print(f"Parsed knowledge: {required_knowledge}")

                except Exception as knowledge_error:
                    print(
                        f"Knowledge extraction failed for job {idx}: {knowledge_error}"
                    )
                    required_knowledge = ["Error extracting knowledge"]

            except Exception as e:
                print(f"OpenAI error for job index {idx}: {e}")
                # fallback to original description
                job_desc = original_job_desc
                required_skills = ["Failed to extract skills"]
                required_knowledge = ["Failed to extract knowledge"]
        else:
            # If not using OpenAI summary
            job_desc = original_job_desc
            if use_openai_summary:
                required_skills = ["OpenAI extraction disabled"]
                required_knowledge = ["OpenAI extraction disabled"]
            else:
                required_skills = ["Enable OpenAI extraction for detailed skills"]
                required_knowledge = ["Enable OpenAI extraction for detailed knowledge"]

        top_matches.append(
            {
                "user_test_id": str(user_test_id),
                "job_index": int(idx),
                "job_title": job.get("Title", "N/A"),
                "job_description": job_desc,
                "similarity_score": similarity_score,
                "similarity_percentage": similarity_percentage,
                "required_skills": required_skills,
                "required_knowledge": required_knowledge,
            }
        )

    return {"top_matches": top_matches}
