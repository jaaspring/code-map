# backend/assessment_routes_firestore.py

from fastapi import APIRouter
from schemas.assessment import (
    UserResponses,
    SkillReflectionRequest,
    FollowUpResponses,
    JobMatch,
    UserProfileMatchResponse,
)
from services.questions_generation_service import generate_questions
from services.charts_generation_service import (
    compute_and_save_charts_for_all_jobs,
)
from services.embedding_service import (
    create_user_embedding,
    match_user_to_job,
    analyze_user_skills_knowledge,
)
from services.skill_gap_analysis_service import compute_skill_gaps_for_all_jobs
from services.report_generation_service import get_report_data
from models.firestore_models import (
    create_user_test,
    add_user_skills_knowledge,
    add_generated_question,
    add_career_recommendation,
    add_job_match,
)
from core.database import db  # Firestore client

router = APIRouter()


# -----------------------------
# Submit user test responses
# -----------------------------
@router.post("/submit-test")
def submit_test(data: UserResponses):
    doc_data = {
        "educationLevel": data.educationLevel,
        "cgpa": data.cgpa,
        "thesisTopic": data.thesisTopic,
        "major": data.major,
        "programmingLanguages": data.programmingLanguages,
        "courseworkExperience": data.courseworkExperience,
        "skillReflection": data.skillReflection,
        "thesisFindings": data.thesisFindings,
        "careerGoals": data.careerGoals,
    }
    user_id = create_user_test(doc_data)
    add_user_skills_knowledge(user_id, skills=[], knowledge=[])
    return {"message": "Data saved successfully", "id": user_id}


# -----------------------------
# Generate follow-up questions
# -----------------------------
@router.post("/generate-questions")
def create_follow_up_questions(data: SkillReflectionRequest):
    user_ref = db.collection("user_tests").document(data.user_test_id).get()
    if not user_ref.exists:
        return {"error": "User not found"}

    doc = user_ref.to_dict()
    skill_reflection = user_ref.to_dict().get("skillReflection")
    thesis_findings = user_ref.to_dict().get("thesisFindings")
    career_goals = user_ref.to_dict().get("careerGoals")

    if not skill_reflection and not thesis_findings and not career_goals:
        return {"error": "Insufficient data to generate questions"}

    # pass all three into service (allowing service to handle None/empty)
    result = generate_questions(
        skill_reflection=skill_reflection,
        thesis_findings=thesis_findings,
        career_goals=career_goals,
    )
    raw_questions = result.get("questions", [])

    saved_questions = []
    for q in raw_questions:
        try:
            question_id = add_generated_question(
                user_id=data.user_test_id,
                question_text=q.get("question", ""),
                options=q.get("options", []),
                answer=q.get("answer", ""),
                difficulty=q.get("difficulty", "easy"),
                question_type=q.get("category", "general"),
            )
            saved_questions.append(
                {
                    "id": question_id,
                    "question": q.get("question", ""),
                    "options": q.get("options", []),
                    "answer": q.get("answer", ""),
                    "difficulty": q.get("difficulty", "easy"),
                    "category": q.get("category", "general"),
                }
            )
        except Exception as e:
            print(f"[ERROR] Failed to save question: {str(e)}")

    return {"questions": saved_questions}


# -----------------------------
# Submit follow-up answers
# -----------------------------
@router.post("/submit-follow-up")
def submit_follow_up(data: FollowUpResponses):
    for resp in data.responses:
        try:
            db.collection("follow_up_answers").document().set(
                {
                    "user_test_id": resp.user_test_id,
                    "question_id": resp.questionId,
                    "selected_option": resp.selectedOption,
                }
            )
        except Exception as e:
            print(f"[ERROR] Failed to save follow-up answer: {str(e)}")
    return {"message": "Follow-up answers saved successfully"}


# -----------------------------
# Generate user profile and job matches
# -----------------------------
@router.post("/user-profile-match", response_model=UserProfileMatchResponse)
def user_profile_match(request: SkillReflectionRequest):
    user_ref = db.collection("user_tests").document(request.user_test_id).get()
    if not user_ref.exists:
        return UserProfileMatchResponse(
            profile_text="",
            top_matches=[],
            error=f"User test ID {request.user_test_id} not found",
        )

    user_data = create_user_embedding(request.user_test_id)
    if not user_data or "error" in user_data:
        return UserProfileMatchResponse(
            profile_text="",
            top_matches=[],
            error=f"User embedding failed: {user_data.get('error', 'Unknown error') if user_data else 'No data returned'}",
        )

    # Analyze skills/knowledge
    try:
        skills_knowledge_result = analyze_user_skills_knowledge(request.user_test_id)
        if skills_knowledge_result and "error" not in skills_knowledge_result:
            print(
                f"[INFO] Skills/Knowledge saved for user_test_id {request.user_test_id}"
            )
            print(f"Extracted skills: {skills_knowledge_result.get('skills', [])}")
            print(
                f"Extracted knowledge: {skills_knowledge_result.get('knowledge', [])}"
            )
    except Exception as e:
        print(f"[ERROR] Skills/Knowledge analysis failed: {str(e)}")

    # Match jobs
    matches = match_user_to_job(request.user_test_id, user_data.get("user_embedding"))
    if not matches or "error" in matches:
        return UserProfileMatchResponse(
            profile_text=user_data.get("profile_text", ""),
            top_matches=[],
        )

    # Save into Firestore
    try:
        rec_id = add_career_recommendation(
            request.user_test_id, profile_text=user_data.get("profile_text", "")
        )
        for job in matches.get("top_matches", []):
            add_job_match(
                recommendation_id=rec_id,
                job_id=str(job.get("job_index", "")),
                job_title=job.get("job_title", ""),
                job_description=job.get("job_description", ""),
                similarity_score=job.get("similarity_score", 0.0),
                similarity_percentage=job.get("similarity_percentage", 0.0),
                required_skills=job.get("required_skills", {}),
                required_knowledge=job.get("required_knowledge", {}),
            )
    except Exception as e:
        print(f"[ERROR] Failed to save career recommendation/job matches: {str(e)}")

    top_matches_list = [
        JobMatch(
            job_index=str(job.get("job_index", "")),
            job_title=job.get("job_title", ""),
            job_description=job.get("job_description", ""),
            similarity_score=job.get("similarity_score", 0.0),
            similarity_percentage=job.get("similarity_percentage", 0.0),
            required_skills=job.get("required_skills", {}),
            required_knowledge=job.get("required_knowledge", {}),
        )
        for job in matches.get("top_matches", [])
    ]

    return UserProfileMatchResponse(
        profile_text=user_data.get("profile_text", ""),
        top_matches=top_matches_list,
    )


# -----------------------------
# Skill & Knowledge Gap Analysis for All Jobs
# -----------------------------
@router.post("/gap-analysis/all/{user_test_id}")
def run_gap_analysis_all(user_test_id: str):
    results = compute_skill_gaps_for_all_jobs(user_test_id)
    if isinstance(results, dict) and results.get("error"):
        return {"error": results["error"]}
    return {"message": "Skill gaps computed", "data": results}


# -----------------------------
# Charts for All Jobs
# -----------------------------
@router.post("/generate-charts/all/{user_test_id}")
def run_charts_all(user_test_id: str):
    results = compute_and_save_charts_for_all_jobs(user_test_id)
    if isinstance(results, dict) and results.get("error"):
        return {"error": results["error"]}
    return {"message": "Charts computed", "data": results}


# -----------------------------
# Report Retrieval
# -----------------------------
@router.get("/report-retrieval/{user_test_id}/{job_index}")
def get_report(user_test_id: str, job_index: str):
    """Retrieve complete report data including saved charts."""
    report_data = get_report_data(user_test_id, job_index)

    if "error" in report_data:
        return report_data

    return {"message": "Report retrieved successfully", "data": report_data}
