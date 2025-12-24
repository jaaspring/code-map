import os
import re
import json
from typing import Any, Dict, List
from dotenv import load_dotenv
import openai
import numpy as np
import core.model_loader as loader
from core.database import db
from schemas.assessment import UserResponses
from services.pinecone_service import PineconeService
from services.scoring_service import calculate_score
from models.firestore_models import (
    get_follow_up_answers_by_user,
    get_generated_questions,
    add_user_skills_knowledge,
    get_latest_attempt_number,
)

# -----------------------------
# Env & OpenAI client
# -----------------------------
load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found. Please set it in your .env file.")

client = openai.OpenAI(api_key=OPENAI_API_KEY)

# initialize Pinecone service
pinecone_service = PineconeService(index_name="code-map")


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
    # fetch Firestore doc (dict)
    doc_ref = db.collection("user_tests").document(user_test_id).get()
    if not doc_ref.exists:
        return {"error": f"No user responses found for {user_test_id}"}

    doc = doc_ref.to_dict()

    try:
        # convert dict → Pydantic model
        user_res = UserResponses(**doc)

        latest_attempt = get_latest_attempt_number(user_test_id)
        print(f"Latest attempt for user_test_id {user_test_id}: {latest_attempt}")

        # fetch all data once
        follow_ups = get_follow_up_answers_by_user(user_test_id, latest_attempt)
        user_questions = get_generated_questions(user_test_id, latest_attempt)

        # build lookup table for O(1) question match
        question_lookup = {q["id"]: q for q in user_questions}

        # build results for scoring
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

        # calculate score (how true the skill reflection is)
        score_result = calculate_score(results)

        # normalize programmingLanguages to a list (in case stored as JSON/text)
        prog_langs = user_res.programmingLanguages
        if isinstance(prog_langs, str):
            prog_langs = [p.strip() for p in prog_langs.split(",") if p.strip()]

        # build combined data
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
            "attempt_number": latest_attempt,
        }
        return combined_data

    except Exception as e:
        # in case Firestore doc has unexpected fields/types
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

        # remove code block markers if present
        if cleaned_response.startswith("```json"):
            cleaned_response = cleaned_response[7:]
        elif cleaned_response.startswith("```"):
            cleaned_response = cleaned_response[3:]
        if cleaned_response.endswith("```"):
            cleaned_response = cleaned_response[:-3]
        cleaned_response = cleaned_response.strip()

        # parse JSON
        result = json.loads(cleaned_response)

        # store as JSON dicts
        skills_dict = result.get("skills", {})
        knowledge_dict = result.get("knowledge", {})

        try:
            add_user_skills_knowledge(
                user_test_id=str(user_test_id),
                skills=skills_dict,
                knowledge=knowledge_dict,
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
    print(f"=== CREATE_USER_EMBEDDING DEBUG ===")
    combined_data = get_user_embedding_data(user_test_id)
    print(
        f"Combined data: {'error' in combined_data if isinstance(combined_data, dict) else 'Not dict'}"
    )

    if "error" in combined_data:
        print(f"Error in combined_data: {combined_data.get('error')}")
        return combined_data

    profile_text = generate_user_profile_text(combined_data)
    print(f"Profile text generated: {len(profile_text) if profile_text else 0} chars")

    user_embedding = loader.get_embeddings(profile_text)
    print(
        f"Embedding generated: {len(user_embedding) if user_embedding else 0} dimensions"
    )

    return {
        "user_test_id": user_test_id,
        "profile_text": profile_text,
        "user_embedding": user_embedding,
        "combined_data": combined_data,
    }


# -----------------------------
# Helper functions for OpenAI parsing
# -----------------------------
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

        # try to parse as JSON
        parsed_data = json.loads(cleaned_text)

        # validate it's a dictionary
        if not isinstance(parsed_data, dict):
            print(f"Warning: {response_type} response is not a dictionary")
            return {}

        return parsed_data

    except json.JSONDecodeError as e:
        print(f"JSON decode error for {response_type}: {e}")
        print(f"Raw response: {response_text}")

        # try to extract JSON from malformed response
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


# -----------------------------
# Store user in Pinecone
# -----------------------------
def store_user_in_pinecone(user_test_id: str) -> Dict[str, Any]:
    """
    Create embedding exactly like original version and store EVERYTHING
    (including full combined_data) into Pinecone metadata.
    """

    # build combined_data (full dict)
    combined_data = get_user_embedding_data(user_test_id)
    if "error" in combined_data:
        return combined_data

    # generate profile text from combined_data
    profile_text = generate_user_profile_text(combined_data)

    # create embedding
    user_embedding = loader.get_embeddings(profile_text)

    # pack metadata
    metadata = {
        "profile_text": profile_text,
        "combined_data": json.dumps(combined_data),
    }

    try:
        pinecone_service.upsert_user(
            user_test_id=user_test_id,
            embedding=user_embedding,
            metadata=metadata,
        )

        return {
            "success": True,
            "user_test_id": user_test_id,
            "message": "User stored in Pinecone successfully",
        }

    except Exception as e:
        return {"error": f"Failed to store user in Pinecone: {str(e)}"}


# -----------------------------
# Extract job skills and knowledge
# -----------------------------
def extract_job_skills_knowledge(job_description: str) -> Dict[str, Any]:
    """
    Extract skills and knowledge from job description using OpenAI
    """
    try:
        skills_prompt = (
            "ANALYZE THIS JOB DESCRIPTION AND EXTRACT ALL REQUIRED SKILLS WITH PROFICIENCY LEVELS:\n\n"
            f"{job_description}\n\n"
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
            f"{job_description}\n\n"
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
            "7. If multiple knowledge areas are mentioned together, create separate entries for each.\n"
            "8. DO NOT include explanations, markdown, or code blocks.\n\n"
            "EXAMPLE OUTPUT:\n"
            '{"Algorithms": "Basic", "Machine Learning": "Advanced", "Database Systems": "Intermediate"}'
        )

        # Extract skills
        skills_response = call_openai(skills_prompt, max_tokens=300)
        skills_dict = parse_json_response(skills_response, "skills")

        # Extract knowledge
        knowledge_response = call_openai(knowledge_prompt, max_tokens=300)
        knowledge_dict = parse_json_response(knowledge_response, "knowledge")

        return {"skills": skills_dict, "knowledge": knowledge_dict}

    except Exception as e:
        print(f"Error extracting skills/knowledge: {e}")
        return {"skills": {}, "knowledge": {}}


# -----------------------------
# Match user to job (Pinecone version)
# -----------------------------
def match_user_to_job(
    user_test_id: str,
    user_embedding: List[float],
    use_openai_summary: bool = True,
) -> Dict[str, Any]:
    """
    Query Pinecone for similar jobs using user embedding.
    """
    try:
        print(f"=== MATCH_USER_TO_JOB DEBUG ===")
        print(f"User test ID: {user_test_id}")
        print(f"User embedding type: {type(user_embedding)}")
        print(f"User embedding length: {len(user_embedding) if user_embedding else 0}")
        print(
            f"User embedding sample: {user_embedding[:5] if user_embedding else 'None'}"
        )

        # query Pinecone for similar jobs
        similar_jobs = pinecone_service.query_similar_jobs(
            user_embedding=user_embedding, top_k=3
        )

        print(f"Similar jobs found: {len(similar_jobs) if similar_jobs else 0}")
        print(f"Similar jobs: {similar_jobs}")

        if not similar_jobs:
            print("No similar jobs found in Pinecone")
            return {"error": "No matching jobs found"}

        print(f"Found {len(similar_jobs)} potential job matches")
        top_matches = []

        for i, job_match in enumerate(similar_jobs):
            similarity_score = job_match["score"]
            similarity_percentage = round(similarity_score * 100, 2)
            job_metadata = job_match["metadata"]

            # extract job details from metadata
            job_title = job_metadata.get("title", "N/A")
            original_job_desc = job_metadata.get("description", "N/A")
            job_id = job_metadata.get(
                "job_id", job_match["id"]
            )  # use match ID as fallback

            # initialize with metadata values
            job_desc = original_job_desc
            required_skills = {}
            required_knowledge = {}

            # try to parse skills/knowledge from metadata
            try:
                if job_metadata.get("required_skills"):
                    required_skills = json.loads(
                        job_metadata.get("required_skills", "{}")
                    )
                if job_metadata.get("required_knowledge"):
                    required_knowledge = json.loads(
                        job_metadata.get("required_knowledge", "{}")
                    )
            except json.JSONDecodeError:
                print(f"Failed to parse skills/knowledge for job {job_id}")

            # generate cleaned/comprehensive description using OpenAI if requested
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

                    job_desc = call_openai(summary_prompt, max_tokens=400)
                    print(f"Generated OpenAI summary for job: {job_title}")

                    # only extract skills/knowledge if not already in metadata
                    if not required_skills or not required_knowledge:
                        extraction_result = extract_job_skills_knowledge(
                            original_job_desc
                        )
                        if not required_skills:
                            required_skills = extraction_result.get("skills", {})
                        if not required_knowledge:
                            required_knowledge = extraction_result.get("knowledge", {})

                except Exception as e:
                    print(f"OpenAI error for job {job_id}: {e}")
                    # keep original values if OpenAI fails

            # Build match data
            match_data = {
                "user_test_id": str(user_test_id),
                "job_index": i,  # MUST be 0, 1, 2
                "job_title": job_title,
                "job_description": job_desc,
                "similarity_score": similarity_score,
                "similarity_percentage": similarity_percentage,
                "required_skills": required_skills,
                "required_knowledge": required_knowledge,
            }

            top_matches.append(match_data)

        print(f"Returning {len(top_matches)} top matches")

        return {"top_matches": top_matches}

    except Exception as e:
        error_msg = f"Failed to query jobs from Pinecone: {str(e)}"
        print(error_msg)
        return {"error": error_msg}


# -----------------------------
# Legacy function for local matching (fallback)
# -----------------------------
def match_user_to_job_legacy(
    user_test_id: str,
    user_embedding: List[float],
    use_openai_summary: bool = True,
) -> Dict[str, Any]:
    """
    Legacy function using local embeddings if Pinecone fails.
    Only use this as a fallback.
    """
    print("Using LEGACY local matching (Pinecone may not be available)")

    # check if globals are loaded correctly
    print(
        f"DF length: {len(loader.df)}, Job embeddings length: {len(loader.job_embeddings)}"
    )

    if loader.df.empty or not loader.job_embeddings:
        return {"error": "No jobs or embeddings available."}

    # convert to numpy
    user_vec = np.array(user_embedding).reshape(1, -1)  # (1, dim)
    job_matrix = np.array(loader.job_embeddings)  # (num_jobs, dim)

    # compute cosine similarity
    from sklearn.metrics.pairwise import cosine_similarity

    similarities = cosine_similarity(user_vec, job_matrix)[0]  # shape: (num_jobs,)

    # get indices of top 3 jobs (sorted by similarity score)
    top_n = min(3, len(similarities))

    # get sorted indices
    sorted_indices = np.argsort(similarities)[::-1]  # highest first

    # deduplicate by job title before slicing
    seen_titles = set()
    unique_indices = []
    for idx in sorted_indices:
        title = loader.df.iloc[idx].get("Title", "N/A")
        if title not in seen_titles:
            seen_titles.add(title)
            unique_indices.append(idx)
        if len(unique_indices) >= top_n:
            break

    top_matches = []

    for idx in unique_indices:
        job = loader.df.iloc[idx]
        similarity_score = float(similarities[idx])
        similarity_percentage = round(similarity_score * 100, 2)
        original_job_desc = job.get("Full Job Description", "N/A")

        # process with OpenAI if requested
        job_desc = original_job_desc
        required_skills = {}
        required_knowledge = {}

        if use_openai_summary and original_job_desc != "N/A":
            extraction_result = extract_job_skills_knowledge(original_job_desc)
            required_skills = extraction_result.get("skills", {})
            required_knowledge = extraction_result.get("knowledge", {})

        top_matches.append(
            {
                "user_test_id": user_test_id,
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
