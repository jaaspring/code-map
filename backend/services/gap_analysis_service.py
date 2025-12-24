from models.firestore_models import (
    get_job_by_index,
    get_user_skills_knowledge,
    get_all_jobs,
    get_recommendation_id_by_user_test_id,
    set_user_job_skill_match,
)

LEVEL_ORDER = {"Not Provided": 0, "Basic": 1, "Intermediate": 2, "Advanced": 3}


def compute_gaps_for_all_jobs(user_test_id: str):
    print(f"=== GAP ANALYSIS DEBUG START for {user_test_id} ===")

    # retrieve recommendation id from career recommendations
    rec_id = get_recommendation_id_by_user_test_id(user_test_id)
    if not rec_id:
        print(f"ERROR: No recommendation ID found for {user_test_id}")
        return {"error": "No career recommendation found for this user test ID."}

    print(f"[DEBUG] Found recommendation ID: {rec_id}")

    # retrieve all job matches from career recommendations for this recommendation
    recommended_jobs = get_all_jobs(rec_id)
    print(f"[DEBUG] Found {len(recommended_jobs)} recommended jobs")

    if not recommended_jobs:
        print(f"ERROR: No jobs found for recommendation {rec_id}")
        return {"error": "No jobs found for this recommendation."}

    # Log each job
    for i, job in enumerate(recommended_jobs):
        print(f"  Job {i}: index={job.get('job_index')}, title={job.get('job_title')}")

    results = []

    # compute gaps
    for job in recommended_jobs:
        job_index = job.get("job_index")
        if not job_index:
            print(f"[WARNING] Job missing job_index: {job}")
            continue

        print(f"\n[DEBUG] Processing job_index: {job_index}")

        # CRITICAL: Check what compare_and_save returns
        gap_result = compare_and_save(user_test_id, str(job_index))

        print(
            f"[DEBUG] compare_and_save returned: {gap_result.keys() if isinstance(gap_result, dict) else 'Not a dict'}"
        )

        if "error" in gap_result:
            print(f"[ERROR] compare_and_save failed: {gap_result['error']}")
            # Continue with next job instead of stopping
            continue

        results.append(
            {
                "job_index": str(job_index),
                "job_title": gap_result.get("job_title", job.get("job_title", "N/A")),
                "gap_analysis": gap_result.get("gap_analysis", {}),
            }
        )

    print(f"\n[DEBUG] Total results computed: {len(results)}")
    print(f"=== GAP ANALYSIS DEBUG END ===")

    if not results:
        return {"error": "Failed to compute any gap analyses"}

    return results


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


def compare_and_save(user_test_id: str, job_match_id: str):
    print(
        f"\n=== COMPARE_AND_SAVE DEBUG for user={user_test_id}, job={job_match_id} ==="
    )

    # check user data
    user_data = get_user_skills_knowledge(user_test_id)
    print(f"[DEBUG] get_user_skills_knowledge returned: {type(user_data)}")
    print(f"[DEBUG] User data exists: {bool(user_data)}")

    if not user_data:
        print(f"[ERROR] No user skills/knowledge found for {user_test_id}")
        print(
            f"[DEBUG] This means Firestore has no document at: user_tests/{user_test_id}"
        )
        print(
            f"[DEBUG] Or the document exists but has no 'skills' or 'knowledge' fields"
        )
        return {
            "gap_analysis": {"skills": {}, "knowledge": {}},
            "job_title": "N/A",
            "error": f"No user skill data for {user_test_id}",
        }

    # log what user data we found
    print(f"[DEBUG] User skills: {list(user_data.get('skills', {}).keys())[:5]}...")
    print(
        f"[DEBUG] User knowledge: {list(user_data.get('knowledge', {}).keys())[:5]}..."
    )

    # check job data
    job_data = get_job_by_index(job_match_id)
    print(f"[DEBUG] get_job_by_index returned: {type(job_data)}")
    print(f"[DEBUG] Job data exists: {bool(job_data)}")

    if not job_data:
        print(f"[ERROR] No job data found for index {job_match_id}")
        return {
            "gap_analysis": {"skills": {}, "knowledge": {}},
            "job_title": "N/A",
            "error": f"No job data for index {job_match_id}",
        }

    # log job data
    print(f"[DEBUG] Job title: {job_data.get('job_title', 'N/A')}")
    print(
        f"[DEBUG] Job required skills: {list(job_data.get('required_skills', {}).keys())[:5]}..."
    )

    user_skills = user_data.get("skills", {})
    user_knowledge = user_data.get("knowledge", {})
    req_skills = job_data.get("required_skills", {})
    req_knowledge = job_data.get("required_knowledge", {})

    print(
        f"[DEBUG] User has {len(user_skills)} skills, {len(user_knowledge)} knowledge items"
    )
    print(
        f"[DEBUG] Job requires {len(req_skills)} skills, {len(req_knowledge)} knowledge items"
    )

    gap_analysis = {"skills": {}, "knowledge": {}}

    # compare skills
    skill_count = 0
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
        skill_count += 1

    print(f"[DEBUG] Compared {skill_count} skills")

    # compare knowledge
    knowledge_count = 0
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
        knowledge_count += 1

    print(f"[DEBUG] Compared {knowledge_count} knowledge items")
    print(
        f"[DEBUG] Gap analysis has {len(gap_analysis['skills'])} skills, {len(gap_analysis['knowledge'])} knowledge"
    )

    # save to Firestore
    try:
        print(
            f"[DEBUG] Saving to user_tests/{user_test_id}/job_skill_matches/{job_match_id}"
        )
        set_user_job_skill_match(
            user_id=user_test_id,
            job_match_id=job_match_id,
            skill_status=gap_analysis["skills"],
            knowledge_status=gap_analysis["knowledge"],
            job_title=job_data.get("job_title", "N/A"),
        )
        print(f"[DEBUG] Successfully saved job skill match")
    except Exception as e:
        print(f"[ERROR] Failed to save job skill match: {e}")

    print(f"=== COMPARE_AND_SAVE COMPLETE ===\n")

    return {"gap_analysis": gap_analysis, "job_title": job_data.get("job_title", "N/A")}
