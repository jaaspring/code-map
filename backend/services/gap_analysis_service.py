from models.firestore_models import (
    get_job_by_index,
    get_user_skills_knowledge,
    get_all_jobs,
    get_recommendation_id_by_user_test_id,
    set_user_job_match,
)

LEVEL_ORDER = {"Not Provided": 0, "Basic": 1, "Intermediate": 2, "Advanced": 3}


def compute_gaps_for_jobs(user_test_id: str, rec_id: str, jobs: list):
    """
    Compute skill & knowledge gaps for a list of recommended jobs.
    Does NOT fetch jobs itself.
    """
    results = []

    for job in jobs:
        job_index = job.get("job_index")
        if not job_index:
            continue

        # Compute gaps for this job
        gap_result = compare_and_save(user_test_id, job_index, rec_id)

        if "error" in gap_result:
            continue

        results.append(
            {
                "job_index": job_index,
                "job_title": gap_result.get("job_title", job.get("job_title", "N/A")),
                "gap_analysis": gap_result.get("gap_analysis", {}),
            }
        )

    return results


# def compute_gaps_for_all_jobs(user_test_id: str):
#     print(f"=== GAP ANALYSIS DEBUG START for {user_test_id} ===")

#     # retrieve recommendation id from career recommendations
#     rec_id = get_recommendation_id_by_user_test_id(user_test_id)
#     if not rec_id:
#         print(f"ERROR: No recommendation ID found for {user_test_id}")
#         return {"error": "No career recommendation found for this user test ID."}

#     print(f"[DEBUG] Found recommendation ID: {rec_id}")

#     # retrieve all job matches from career recommendations for this recommendation
#     recommended_jobs = get_all_jobs(rec_id)
#     print(f"[DEBUG] Found {len(recommended_jobs)} recommended jobs")

#     if not recommended_jobs:
#         print(f"ERROR: No jobs found for recommendation {rec_id}")
#         return {"error": "No jobs found for this recommendation."}

#     # Log each job
#     for i, job in enumerate(recommended_jobs):
#         print(f"  Job {i}: index={job.get('job_index')}, title={job.get('job_title')}")

#     results = []

#     # compute gaps
#     for job in recommended_jobs:
#         job_index = job.get("job_index")
#         if not job_index:
#             print(f"[WARNING] Job missing job_index: {job}")
#             continue

#         print(f"\n[DEBUG] Processing job_index: {job_index}")

#         # CRITICAL: Check what compare_and_save returns
#         gap_result = compare_and_save(user_test_id, str(job_index))

#         print(
#             f"[DEBUG] compare_and_save returned: {gap_result.keys() if isinstance(gap_result, dict) else 'Not a dict'}"
#         )

#         if "error" in gap_result:
#             print(f"[ERROR] compare_and_save failed: {gap_result['error']}")
#             # Continue with next job instead of stopping
#             continue

#         results.append(
#             {
#                 "job_index": str(job_index),
#                 "job_title": gap_result.get("job_title", job.get("job_title", "N/A")),
#                 "gap_analysis": gap_result.get("gap_analysis", {}),
#             }
#         )

#     print(f"\n[DEBUG] Total results computed: {len(results)}")
#     print(f"=== GAP ANALYSIS DEBUG END ===")

#     if not results:
#         return {"error": "Failed to compute any gap analyses"}

#     return results


def compute_gap_for_single_job(user_test_id: str, job_index: str):
    """
    Compute gap analysis for a single job only
    """
    print(f"[DEBUG] Computing gap for single job index: {job_index}")

    # get recommendation ID
    rec_id = get_recommendation_id_by_user_test_id(user_test_id)
    if not rec_id:
        return {"error": "No career recommendation found for this user test ID."}

    print(f"[DEBUG] Found recommendation ID: {rec_id}")

    # compute gap for this specific job
    print(f"[DEBUG] Calling compare_and_save for job {job_index}")
    gap_result = compare_and_save(user_test_id, job_index)

    print(f"[DEBUG] compare_and_save result: {gap_result}")

    if "error" in gap_result:
        return {"error": gap_result["error"]}

    # return single job's gap analysis
    return {
        "job_index": job_index,
        "job_title": gap_result.get("job_title", "N/A"),
        "gap_analysis": gap_result.get("gap_analysis", {}),
    }


def compare_and_save(user_test_id: str, job_match_id: str, rec_id: str):
    user_data = get_user_skills_knowledge(user_test_id)
    job_data = get_job_by_index(rec_id, job_match_id)

    if not user_data or not job_data:
        return {"gap_analysis": {}, "job_title": "N/A", "error": "Missing data"}

    gap_analysis = {"skills": {}, "knowledge": {}}

    # skills comparison
    for skill, req_level in job_data.get("required_skills", {}).items():
        user_level = user_data.get("skills", {}).get(skill, "Not Provided")
        status = (
            "Missing"
            if user_level == "Not Provided"
            else (
                "Achieved"
                if LEVEL_ORDER[user_level] >= LEVEL_ORDER[req_level]
                else "Weak"
            )
        )
        gap_analysis["skills"][skill] = {
            "required_level": req_level,
            "user_level": user_level,
            "status": status,
        }

    # knowledge comparison
    for knowledge, req_level in job_data.get("required_knowledge", {}).items():
        user_level = user_data.get("knowledge", {}).get(knowledge, "Not Provided")
        status = (
            "Missing"
            if user_level == "Not Provided"
            else (
                "Achieved"
                if LEVEL_ORDER[user_level] >= LEVEL_ORDER[req_level]
                else "Weak"
            )
        )
        gap_analysis["knowledge"][knowledge] = {
            "required_level": req_level,
            "user_level": user_level,
            "status": status,
        }

    print(
        f"[DEBUG] Saving gap for rec={rec_id}, job={job_match_id}, "
        f"skills={len(gap_analysis['skills'])}, "
        f"knowledge={len(gap_analysis['knowledge'])}"
    )

    # save to Firestore
    try:
        set_user_job_match(
            rec_id=rec_id,
            job_match_id=job_match_id,
            skill_status=gap_analysis["skills"],
            knowledge_status=gap_analysis["knowledge"],
        )
        print(f"[DEBUG] Successfully saved job skill match")
    except Exception as e:
        return {
            "gap_analysis": gap_analysis,
            "job_title": job_data.get("job_title", "N/A"),
            "error": str(e),
        }

    return {"gap_analysis": gap_analysis, "job_title": job_data.get("job_title", "N/A")}
