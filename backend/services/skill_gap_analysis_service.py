from models.firestore_models import (
    get_job_by_index,
    get_user_skills_knowledge,
    get_all_jobs,
    get_recommendation_id_by_user_test_id,
    set_user_job_skill_match,
)

LEVEL_ORDER = {"Not Provided": 0, "Basic": 1, "Intermediate": 2, "Advanced": 3}


def compute_skill_gaps_for_all_jobs(user_test_id: str):
    results = []

    # retrieve recommendation id from career recommendations
    rec_id = get_recommendation_id_by_user_test_id(user_test_id)
    if not rec_id:
        return {"error": "No career recommendation found for this user test ID."}

    # retrieve all job matches from career recommendations for this recommendation
    all_jobs = get_all_jobs()
    if not all_jobs:
        return {"error": "No jobs found for this recommendation."}

    # compute gaps
    for job in all_jobs:
        gap_result = compare_and_save(user_test_id, str(job["job_index"]))

        results.append(
            {
                "job_index": str(job["job_index"]),
                "job_title": gap_result.get("job_title", job.get("job_title", "N/A")),
                "gap_analysis": gap_result.get(
                    "gap_analysis", {}
                ),  #  knowledge_status and skill_status
            }
        )

    return (
        results  # pass computed gap analysis results back to the API route for response
    )


def compare_and_save(user_test_id: str, job_match_id: str):
    user_data = get_user_skills_knowledge(user_test_id)
    if not user_data:
        return {"gap_analysis": {"skills": {}, "knowledge": {}}, "job_title": "N/A"}

    job_data = get_job_by_index(job_match_id)
    if not job_data:
        return {"gap_analysis": {"skills": {}, "knowledge": {}}, "job_title": "N/A"}

    user_skills = user_data.get("skills", {})
    user_knowledge = user_data.get("knowledge", {})
    req_skills = job_data.get("required_skills", {})
    req_knowledge = job_data.get("required_knowledge", {})

    gap_analysis = {"skills": {}, "knowledge": {}}

    # Compare skills
    for skill, req_level in req_skills.items():
        user_level = user_skills.get(skill, "Not Provided")
        if user_level == "Not Provided":
            status = "Missing"
        elif LEVEL_ORDER[user_level] >= LEVEL_ORDER[req_level]:
            status = "Achieved"
        else:
            status = "Weak"

        gap_analysis["skills"][skill] = {
            "required_level": req_level,
            "user_level": user_level,
            "status": status,
        }

    # Compare knowledge
    for knowledge, req_level in req_knowledge.items():
        user_level = user_knowledge.get(knowledge, "Not Provided")
        if user_level == "Not Provided":
            status = "Missing"
        elif LEVEL_ORDER[user_level] >= LEVEL_ORDER[req_level]:
            status = "Achieved"
        else:
            status = "Weak"

        gap_analysis["knowledge"][knowledge] = {
            "required_level": req_level,
            "user_level": user_level,
            "status": status,
        }

    # ------------------------------------------------------------
    # Synchronous Firestore Save: User–Job Skill Match
    # ------------------------------------------------------------
    # After computing the skill and knowledge gap between the user's profile
    # and a specific job's requirements, this section stores the results
    # permanently in Firestore.
    #
    # The function below creates a document in:
    #   user_tests/{user_id}/job_skill_matches/{job_match_id}
    #
    # Each document represents a job comparison for a single user and includes:
    #   • job_match_id       → The job’s unique index or identifier
    #   • job_title          → The job’s title for readability
    #   • skill_status       → Detailed comparison of required vs. user skill levels
    #   • knowledge_status   → Detailed comparison of required vs. user knowledge levels
    #
    # Synchronous means the Firestore write operation is performed directly
    # (blocking) without async/await. The function will not continue executing
    # until the data is successfully written to the database.
    # ------------------------------------------------------------
    set_user_job_skill_match(
        user_id=user_test_id,
        job_match_id=job_match_id,
        skill_status=gap_analysis["skills"],
        knowledge_status=gap_analysis["knowledge"],
        job_title=job_data.get("job_title", "N/A"),
    )

    return {"gap_analysis": gap_analysis, "job_title": job_data.get("job_title", "N/A")}
