from models.firestore_models import (
    get_all_jobs,
    get_profile_text_by_user,
    get_job_by_index,
    get_job_charts,
    get_recommendation_id_by_user_test_id,
    get_user_attempts,
)


def get_report_data(user_test_id: str, job_index: str):
    profile_text = get_profile_text_by_user(user_test_id)

    rec_id = get_recommendation_id_by_user_test_id(user_test_id)
    if not rec_id:
        return {
            "error": f"No career recommendation found for user_test_id {user_test_id}"
        }

    jobs_list = get_all_jobs(rec_id)
    if not jobs_list:
        return {"error": f"No jobs found for recommendation {rec_id}"}

    # map frontend index → job_index
    try:
        idx = int(job_index)
        job_index_internal = jobs_list[idx]["job_index"]
    except (IndexError, ValueError):
        return {"error": f"Job index {job_index} is invalid"}

    job_data = get_job_by_index(rec_id, job_index_internal)
    if not job_data:
        return {"error": f"Job with index {job_index_internal} not found"}

    # get latest attempt number
    attempts = get_user_attempts(user_test_id)  # returns list of dicts
    if not attempts:
        attempt_number = 1  # fallback
    else:
        attempt_number = max(a["attemptNumber"] for a in attempts)

    # fetch charts for this attempt
    charts_data = get_job_charts(
        rec_id, job_index_internal, attempt_number=attempt_number
    )
    charts_ready = bool(charts_data)

    return {
        "user_test_id": user_test_id,
        "recommendation_id": rec_id,
        "profile_text": profile_text,
        "job": job_data,
        "charts": charts_data or {},
        "charts_ready": charts_ready,
        "attempt_number": attempt_number,
    }
