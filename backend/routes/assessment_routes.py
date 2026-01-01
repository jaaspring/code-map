# acts as the API endpoint. It receives requests from Dart, performs the computation or data retrieval, and returns a response.

from fastapi import APIRouter, Body, Query
from schemas.assessment import (
    FollowUpResponses,
    JobMatch,
    UserProfileMatchResponse,
    UserResponses,
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
from services.gap_analysis_service import (
    compute_gap_for_single_job,
    compute_gaps_for_jobs,
)
from services.report_generation_service import get_report_data
from models.firestore_models import (
    create_user_test,
    add_user_skills_knowledge,
    add_generated_question,
    get_all_jobs,
    get_generated_questions,
    add_career_recommendation,
    add_job_match,
    get_job_matches,
    get_recommendation_id_by_user_test_id,
    get_user_test,
)
from services.career_roadmaps_service import (
    compute_career_roadmaps,
    retrieve_career_roadmap,
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
        "careerGoals": data.careerGoals,
        "testId": data.userTestId, # store it in doc for reference
    }
    user_test_id = create_user_test(doc_data, data.userTestId)
    add_user_skills_knowledge(user_test_id, skills=[], knowledge=[])
    return {"message": "Data saved successfully", "id": user_test_id}


# -----------------------------
# Generate follow-up questions
# -----------------------------
@router.post("/generate-questions")
def create_follow_up_questions(user_test_id: str = Body(..., embed=True)):
    # get the user test document
    user_ref = db.collection("user_tests").document(user_test_id).get()
    print(f"Checked user_tests/{user_test_id} - exists: {user_ref.exists}")

    if not user_ref.exists:
        return {"error": "User test not found"}

    # find which user owns this test (look in users collection)
    print(f"Querying users where assessmentAttempts contains testId: {user_test_id}")

    user_query = (
        db.collection("users").where("testIds", "array_contains", user_test_id).limit(1)
    )

    user_docs = list(user_query.stream())
    print(f"Found {len(user_docs)} users with this testId")

    user_doc = user_docs[0]
    user_data = user_doc.to_dict()

    # get the attempt number from assessmentAttempts
    assessment_attempts = user_data.get("assessmentAttempts", [])
    attempt_number = 1  # default if not found

    for attempt in assessment_attempts:
        if attempt.get("testId") == user_test_id:
            attempt_number = attempt.get("attemptNumber", 1)
            break

    print(f"User attempt number for {user_test_id}: {attempt_number}")

    # get reflection data from saved user test document
    user_test_data = user_ref.to_dict()
    skill_reflection = user_test_data.get("skillReflection")
    thesis_findings = user_test_data.get("thesisFindings")
    career_goals = user_test_data.get("careerGoals")

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
                user_id=user_test_id,
                question_text=q.get("question", ""),
                code=q.get("code", None),
                language=q.get("language", None),
                options=q.get("options", []),
                answer=q.get("answer", ""),
                difficulty=q.get("difficulty", "easy"),
                question_type=q.get("category", "general"),
                test_attempt=attempt_number,  # use attempt_number from assessmentAttempts
            )
            saved_questions.append(
                {
                    "id": question_id,
                    "question": q.get("question", ""),
                    "code": q.get("code", None),
                    "language": q.get("language", None),
                    "options": q.get("options", []),
                    "answer": q.get("answer", ""),
                    "difficulty": q.get("difficulty", "easy"),
                    "category": q.get("category", "general"),
                    "test_attempt": attempt_number,
                }
            )
        except Exception as e:
            print(f"[ERROR] Failed to save question: {str(e)}")

    print(f"=== DEBUG END: Generated {len(saved_questions)} questions ===")
    return {"questions": saved_questions}


# -----------------------------
# Retrieve generated follow-up questions
# -----------------------------
@router.post("/get-generated-questions")
def get_all_generated_questions(request: dict):
    user_test_id = request.get("user_test_id")
    attempt_number = request.get("attempt_number", 1)

    questions = get_generated_questions(user_test_id, attempt_number)
    
    # Map question_type to category for frontend compatibility
    for q in questions:
        if "category" not in q and "question_type" in q:
            q["category"] = q["question_type"]
            
    return {"questions": questions}


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
                    "test_attempt": resp.test_attempt,
                }
            )
        except Exception as e:
            print(f"[ERROR] Failed to save follow-up answer: {str(e)}")
    return {"message": "Follow-up answers saved successfully"}


# -----------------------------
# Generate user profile and job matches
# -----------------------------
@router.post(
    "/user-profile-match", response_model=UserProfileMatchResponse
)  # ensures the API response follows this schema and filters extra fields
def user_profile_match(user_test_id: str = Body(..., embed=True)):
    user_ref = db.collection("user_tests").document(user_test_id).get()
    if not user_ref.exists:
        print(f"ERROR: User test not found")
        return UserProfileMatchResponse(
            profile_text="",
            job_matches=[],
            error=f"User test ID {user_test_id} not found",
        )

    user_data = create_user_embedding(user_test_id)
    if not user_data or "error" in user_data:
        return UserProfileMatchResponse(
            profile_text="",
            jop_matches=[],
            error=f"User embedding failed: {user_data.get('error', 'Unknown error') if user_data else 'No data returned'}",
        )

    # analyze skills/knowledge
    try:
        skills_knowledge_result = analyze_user_skills_knowledge(user_test_id)
        if skills_knowledge_result and "error" not in skills_knowledge_result:
            print(f"[INFO] Skills/Knowledge saved for user_test_id {user_test_id}")
            print(f"Extracted skills: {skills_knowledge_result.get('skills', [])}")
            print(
                f"Extracted knowledge: {skills_knowledge_result.get('knowledge', [])}"
            )
    except Exception as e:
        print(f"[ERROR] Skills/Knowledge analysis failed: {str(e)}")

    # match jobs
    matches = match_user_to_job(user_test_id, user_data.get("user_embedding"))

    print(f"Matches found: {matches is not None}")
    print(f"Matches has error: {'error' in matches if matches else 'No matches'}")
    print(
        f"Number of job_matches: {len(matches.get('job_matches', [])) if matches else 0}"
    )

    if not matches or "error" in matches:
        return UserProfileMatchResponse(
            profile_text=user_data.get("profile_text", ""),
            job_matches=[],
        )

    # save into Firestore
    try:
        rec_id = add_career_recommendation(
            user_test_id, profile_text=user_data.get("profile_text", "")
        )
        print(f"SUCCESS: Created career recommendation ID: {rec_id}")

        for job in matches.get("job_matches", []):
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
            print(f"SUCCESS: Saved {len(matches.get('job_matches', []))} job matches")
    except Exception as e:
        print(f"[ERROR] Failed to save career recommendation/job matches: {str(e)}")

    job_matches_list = [
        JobMatch(
            job_index=str(job.get("job_index", "")),
            job_title=job.get("job_title", ""),
            job_description=job.get("job_description", ""),
            similarity_score=job.get("similarity_score", 0.0),
            similarity_percentage=job.get("similarity_percentage", 0.0),
            required_skills=job.get("required_skills", {}),
            required_knowledge=job.get("required_knowledge", {}),
        )
        for job in matches.get("job_matches", [])
    ]

    return UserProfileMatchResponse(
        profile_text=user_data.get("profile_text", ""),
        job_matches=job_matches_list,
    )


# -----------------------------
# Skill & Knowledge Gap Analysis for All Jobs
# -----------------------------
@router.post("/gap-analysis/{user_test_id}")
# FastAPI automatically extracts user_test_id from the URL and passes it as the function argument.
def run_gap_analysis_all(user_test_id: str):
    print(f"[GAP DEBUG] Starting gap analysis for test: {user_test_id}")

    # get recommendation ID based on user_test_id
    rec_id = get_recommendation_id_by_user_test_id(user_test_id)
    print(f"[GAP DEBUG] Found recommendation ID: {rec_id}")

    # get all recommended jobs for this recommendation
    recommended_jobs = get_all_jobs(rec_id)
    print(f"[GAP DEBUG] Found {len(recommended_jobs)} recommended jobs")

    results = compute_gaps_for_jobs(user_test_id, rec_id, recommended_jobs)
    if isinstance(results, dict) and results.get("error"):
        return {"error": results["error"]}
    return {"message": "Skill gaps computed", "data": results}


@router.get("/gap-analysis/{user_test_id}/{job_index}")
def get_gap_analysis_for_single_job(
    user_test_id: str,
    job_index: str,
    attempt: int = Query(1, description="Attempt number"),
):
    print(
        f"[GAP DEBUG] Starting gap analysis for test: {user_test_id}, job: {job_index}, attempt: {attempt}"
    )

    try:
        result = compute_gap_for_single_job(user_test_id, job_index)

        if isinstance(result, dict) and result.get("error"):
            return {"error": result["error"]}

        return {
            "message": "Skill gap computed for single job",
            "data": result,
        }
    except Exception as e:
        print(f"[ERROR] Failed to compute gap analysis: {e}")
        import traceback

        traceback.print_exc()
        return {"error": f"Internal server error: {str(e)}"}


# -----------------------------
# Charts for All Jobs
# -----------------------------
@router.post("/generate-charts/{user_test_id}")
def run_charts_all(user_test_id: str, data: dict = Body(...)):
    """
    Generate charts for all recommended jobs.
    Requires attempt_number in request body.
    """
    # get attempt number from request body
    attempt_number = data.get("attempt_number", 1)

    # pass both parameters to the function
    results = compute_and_save_charts_for_all_jobs(user_test_id, attempt_number)

    if isinstance(results, dict) and results.get("error"):
        return {"error": results["error"]}

    return {"message": "Charts computed", "data": results}


# -----------------------------
# Report Retrieval
# -----------------------------
@router.get("/report-retrieval/{user_test_id}/{job_index}")
# FastAPI automatically extracts user_test_id and job_index from the URL and passes it as the function argument.
def get_report(user_test_id: str, job_index: str):
    """Retrieve complete report data including saved charts."""
    report_data = get_report_data(user_test_id, job_index)

    if "error" in report_data:
        return report_data

    return {"message": "Report retrieved successfully", "data": report_data}


@router.get("/user/{user_id}/recent-test")
def get_recent_user_test(user_id: str):
    """
    Get the most recent user test for a user.
    Returns user_test_id and basic test info.
    """
    test_data = get_user_test(user_id)
    if not test_data:
        return {"error": "No test found for user"}

    return {
        "message": "Recent test found",
        "data": {
            "user_test_id": user_id,
            "test_data": test_data,
        },
    }


# -----------------------------
# Career Roadmaps for All Jobs
# -----------------------------
@router.post(
    "/career-roadmap-generation/all/{user_test_id}"
)  # FastAPI automatically extracts user_test_id from the URL and passes it as the function argument.
def generate_career_roadmaps(user_test_id: str):
    """Retrieve career roadmaps for all jobs."""
    career_roadmap = compute_career_roadmaps(user_test_id)

    if "error" in career_roadmap:
        return career_roadmap

    return {"message": "Career roadmaps generated successfully", "data": career_roadmap}


# -----------------------------
# Career Roadmap Retrieval
# -----------------------------
@router.get("/career-roadmap-retrieval/{user_test_id}/{job_match_id}")
# FastAPI automatically extracts user_test_id and job_index from the URL and passes it as the function argument.
def get_career_roadmap(user_test_id: str, job_match_id: str):
    """Retrieve career roadmap for a specific job."""
    roadmap_data = retrieve_career_roadmap(user_test_id, job_match_id)

    if "error" in roadmap_data:
        return roadmap_data

    return {"message": "Career roadmap retrieved successfully", "data": roadmap_data}


# career recommendations retrieval
@router.get("/career-recommendations/{user_test_id}")
def get_all_recommended_jobs(user_test_id: str):
    """Get all recommended jobs for a user."""
    try:
        # get recommendation ID for the user
        rec_id = get_recommendation_id_by_user_test_id(user_test_id)
        if not rec_id:
            return {"error": "No career recommendation found for this user test ID."}

        # get all job matches for this recommendation
        jobs = get_job_matches(rec_id)

        # format the response with job_index and job_title
        formatted_jobs = []
        for job in jobs:
            # since job_matches documents use job_index as document ID
            # we need to get the document ID as job_index
            # this requires a slight modification to get_job_matches
            formatted_jobs.append(
                {
                    "job_index": job.get("job_index", ""),
                    "job_title": job.get("job_title", "Unknown Title"),
                    "similarity_percentage": job.get("similarity_percentage", 0),
                    "job_description": job.get("job_description", ""),
                    "required_skills": job.get("required_skills", {}),
                }
            )

        return {
            "message": "Recommended jobs retrieved successfully",
            "data": formatted_jobs,
        }
    except Exception as e:
        return {"error": f"Failed to retrieve recommended jobs: {str(e)}"}
