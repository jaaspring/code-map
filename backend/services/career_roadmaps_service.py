import os
import json
import re
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
from models.firestore_models import (
    get_recommendation_id_by_user_test_id,
    create_career_roadmap,
    get_career_roadmap,
    get_user_job_skill_matches,
)

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


def generate_roadmap_with_openai(skill_status: dict, knowledge_status: dict) -> dict:
    """
    Generate career roadmap topics and subtopics using OpenAI.
    Uses the skill_status and knowledge_status from job_skill_matches.
    """

    prompt = f"""
    Create a structured career roadmap based on skill gap analysis:

    Input Data:
    - Skill Status: {skill_status}
    - Knowledge Status: {knowledge_status}

    Task:
    Identify all skills and knowledge areas where:
    - status == "Missing", AND
    - user_level < required_level
    
    Analyze the gaps between user's current level and required level for each skill/knowledge.
    Create a hierarchical roadmap with main topics and subtopics.
    
    Return ONLY a JSON object with this exact structure:
    {{
        "topics": {{
            "Main Topic 1": "Basic/Intermediate/Expert/Advanced",
            "Main Topic 2": "Basic/Intermediate/Expert/Advanced"
        }},
        "sub_topics": {{
            "Main Topic 1": [
                "Subtopic 1",
                "Subtopic 2", 
            ],
            "Main Topic 2": [
                "Subtopic 1",
                "Subtopic 2",
            ]
        }}
    }}
    
    For each affected skill/knowledge area, generate:
    1. A Main Topic (professional, concise, technical)
    2. An appropriate proficiency level (Basic / Intermediate / Advanced / Expert) ONLY
    3. Subtopics that fully cover what the user must learn
        - Subtopics must be: concise, technical, non-generic, actionable
        - Cover the complete domain but avoid unnecessary depth
    """

    try:
        response = llm.invoke(prompt)

        # find JSON in the response
        json_match = re.search(r"\{.*\}", response.content, re.DOTALL)
        if json_match:
            roadmap_data = json.loads(json_match.group())
            return roadmap_data

    except Exception as e:
        print(f"OpenAI API error: {e}")


def resolve_job_match_id(user_test_id: str, job_index: str) -> str:
    """
    Convert UI job_index (0,1,2...) into persistent job_match_id
    """
    job_skill_matches = get_user_job_skill_matches(user_test_id)

    try:
        index = int(job_index)
        return job_skill_matches[index]["job_match_id"]
    except Exception:
        # fallback: already a job_match_id
        return job_index


def compute_career_roadmaps(user_test_id: str) -> dict:
    """
    Compute Career Roadmaps for all jobs based on the given user_test_id.
    Now uses job_skill_matches collection which already has skill gap analysis.
    """
    print(f"compute_career_roadmaps CALLED for user: {user_test_id}")
    try:
        # get all job skill matches for this user test ID
        job_skill_matches = get_user_job_skill_matches(user_test_id)
        print(f"Found {len(job_skill_matches)} job skill matches")

        if not job_skill_matches:
            return {"error": "No job skill matches found for this user test ID."}

        # get the recommendation document ID for this user_test_id
        recommendation_id = get_recommendation_id_by_user_test_id(user_test_id)
        print(f"Recommendation ID: {recommendation_id}")

        if not recommendation_id:
            return {"error": "No recommendation found for this user test ID."}

        # generate roadmap for each job
        generated_roadmaps = {}

        for index, job_match in enumerate(job_skill_matches):
            job_match_id = job_match.get("job_match_id")
            job_title = job_match.get("job_title")
            skill_status = job_match.get("skill_status", {})
            knowledge_status = job_match.get("knowledge_status", {})

            print(f"Processing job {index + 1}: {job_title} (ID: {job_match_id})")
            print(f"Skill status keys: {list(skill_status.keys())}")
            print(f"Knowledge status keys: {list(knowledge_status.keys())}")

            missing_skills = []
            for skill, data in skill_status.items():
                if data.get("status") == "Missing":
                    missing_skills.append(skill)

            for knowledge, data in knowledge_status.items():
                if data.get("status") == "Missing":
                    missing_skills.append(knowledge)

            print(f"Missing skills/knowledge: {missing_skills}")

            # generate roadmap content using OpenAI
            roadmap_content = generate_roadmap_with_openai(
                skill_status, knowledge_status
            )

            print(f"OpenAI response for {job_match_id}:")
            print(f"Topics: {list(roadmap_content.get('topics', {}).keys())}")
            print(
                f"Total subtopics: {sum(len(v) for v in roadmap_content.get('sub_topics', {}).values())}"
            )

            # save to Firestore
            print(f"Writing to Firestore for {job_match_id}")
            create_career_roadmap(
                user_test_id=user_test_id,
                job_match_id=job_match_id,
                rec_id=recommendation_id,
                topics=roadmap_content["topics"],
                sub_topics=roadmap_content["sub_topics"],
            )

            generated_roadmaps[job_match_id] = {
                "job_title": job_title,
                "roadmap": roadmap_content,
            }

        return {
            "message": f"Successfully generated {len(generated_roadmaps)} career roadmaps",
            "data": generated_roadmaps,
        }

    except Exception as e:
        print(f"Error computing career roadmaps: {e}")
        import traceback

        traceback.print_exc()
        return {"error": f"Failed to compute career roadmaps: {str(e)}"}


def retrieve_career_roadmap(user_test_id: str, job_index: str) -> dict:
    try:
        job_match_id = resolve_job_match_id(user_test_id, job_index)

        roadmap = get_career_roadmap(user_test_id, job_match_id)

        if not roadmap:
            return {"error": f"No career roadmap found for job index: {job_index}"}

        return roadmap

    except Exception as e:
        print(f"Error retrieving career roadmap: {e}")
        import traceback

        traceback.print_exc()
        return {"error": f"Failed to retrieve career roadmap: {str(e)}"}
