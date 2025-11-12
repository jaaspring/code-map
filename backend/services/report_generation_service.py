from models.firestore_models import (
    get_profile_text_by_user,
    get_job_by_index,
    get_job_charts,
    get_recommendation_id_by_user_test_id,
)


def get_report_data(user_test_id: str, job_index: str):
    """Combine profile_text, job details, and saved charts into a single report."""
    profile_text = get_profile_text_by_user(user_test_id)
    job_data = get_job_by_index(job_index)

    if not job_data:
        return {"error": f"Job with index {job_index} not found"}

    # Get recommendation ID to locate the charts
    rec_id = get_recommendation_id_by_user_test_id(user_test_id)

    # Get the pre-saved charts from database
    charts_data = get_job_charts(rec_id, job_index)

    report = {
        "user_test_id": user_test_id,
        "recommendation_id": rec_id,
        "profile_text": profile_text,
        "job": job_data,
        "charts": charts_data or {},
    }

    return report
