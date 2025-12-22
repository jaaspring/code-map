from core.database import db
from google.cloud import firestore
from google.cloud.firestore_v1 import FieldFilter


# -----------------------
# UserTest
# -----------------------
def create_user_test(user_id: str, data: dict) -> str:
    """
    Create a new user test document.
    data keys: educationLevel, cgpa, thesisTopic, major, programmingLanguages,
               courseworkExperience, skillReflection, thesisFindings, careerGoals
    Returns the new document ID.
    """
    user_ref = db.collection("user_tests").document()  # auto-ID
    data["user_id"] = user_id  # userId to track
    data["created_at"] = firestore.SERVER_TIMESTAMP
    user_ref.set(data)
    return user_ref.id


def get_user_test(user_id: str) -> dict:
    doc = db.collection("user_tests").document(user_id).get()
    return doc.to_dict() if doc.exists else None


def get_user_tests_by_user(user_id: str) -> list:
    """
    Get all tests for a user, sorted by most recent.
    """
    tests_ref = db.collection("user_tests").where("userId", "==", user_id)
    docs = tests_ref.order_by(
        "created_at", direction=firestore.Query.DESCENDING
    ).stream()

    tests = []
    for doc in docs:
        test_data = doc.to_dict()
        test_data["id"] = doc.id
        tests.append(test_data)

    return tests


# -----------------------
# GeneratedQuestion
# -----------------------
def add_generated_question(
    user_id: str,
    question_text: str,
    code=None,
    language=None,
    options=None,
    answer=None,
    difficulty=None,
    question_type=None,
    test_attempt=None,
) -> str:
    print(
        f"[DEBUG] Saving question with test_attempt={test_attempt} for user={user_id}"
    )
    print(f"[DEBUG] Question text: {question_text[:50]}...")

    question_ref = db.collection("generated_questions").document()
    question_ref.set(
        {
            "user_test_id": user_id,
            "question_text": question_text,
            "code": code,
            "language": language,
            "options": options or [],
            "answer": answer,
            "difficulty": difficulty,
            "question_type": question_type,
            "test_attempt": test_attempt,
            "created_at": firestore.SERVER_TIMESTAMP,
        }
    )
    return question_ref.id


def get_generated_questions(user_id: str, attempt_number: int = 1):
    return [
        {**q.to_dict(), "id": q.id}
        for q in db.collection("generated_questions")
        .where(filter=FieldFilter("user_test_id", "==", user_id))
        .where(
            filter=FieldFilter("test_attempt", "==", attempt_number)
        )  # use attempt_number parameter
        .stream()
    ]


# -----------------------
# FollowUpAnswers
# -----------------------
def add_follow_up_answer(
    user_id: str, question_id: str, selected_option: str, attempt_number: int
) -> str:
    """
    Add a follow-up answer document.
    """
    answer_ref = db.collection("follow_up_answers").document()
    answer_ref.set(
        {
            "user_test_id": user_id,
            "question_id": question_id,
            "selected_option": selected_option,
            "test_attempt": attempt_number,
        }
    )
    return answer_ref.id


def get_follow_up_answers_by_user(user_id: str, attempt_number: int):
    return [
        doc.to_dict()
        for doc in db.collection("follow_up_answers")
        .where(filter=FieldFilter("user_test_id", "==", user_id))
        .where(filter=FieldFilter("test_attempt", "==", attempt_number))
        .stream()
    ]


def get_latest_attempt_number(user_id: str) -> int:
    """
    Get the latest attempt number for a user.
    Returns 1 if no attempts found.
    """

    query = (
        db.collection("follow_up_answers")
        .where("user_test_id", "==", user_id)
        .order_by("test_attempt", direction=firestore.Query.DESCENDING)
        .limit(1)
        .stream()
    )

    for doc in query:
        return doc.to_dict().get("test_attempt", 1)

    return 1  # default if no answers exist


# -----------------------
# CareerRecommendation
# -----------------------
def add_career_recommendation(user_id: str, profile_text: str) -> str:
    rec_ref = db.collection("career_recommendations").document()
    rec_ref.set({"user_test_id": user_id, "profile_text": profile_text})
    return rec_ref.id


def get_all_jobs(rec_id: str = None):
    """
    Fetch all jobs across recommendations.
    If rec_id is provided, fetch jobs only for that recommendation.
    """
    jobs = []
    recs = (
        [rec_id]
        if rec_id
        else [rec.id for rec in db.collection("career_recommendations").stream()]
    )

    for r_id in recs:
        collection = (
            db.collection("career_recommendations")
            .document(r_id)
            .collection("job_matches")
        )
        for job_doc in collection.stream():
            job_data = job_doc.to_dict()
            job_data["job_index"] = job_doc.id
            jobs.append(job_data)
    return jobs


def get_job_by_index(job_index: str):
    """
    Fetch a single job match across all career recommendations by its job_index.
    """
    recs = db.collection("career_recommendations").stream()
    for rec in recs:
        collection = (
            db.collection("career_recommendations")
            .document(rec.id)
            .collection("job_matches")
        )
        job_doc = collection.document(job_index).get()
        if job_doc.exists:
            job_data = job_doc.to_dict()
            job_data["job_index"] = job_index
            return job_data
    return None


def get_jobs_for_recommendation(rec_id: str):
    """
    Fetch all job matches for a specific recommendation.
    """
    jobs = []
    collection = (
        db.collection("career_recommendations")
        .document(rec_id)
        .collection("job_matches")
    )
    for job_doc in collection.stream():
        job_data = job_doc.to_dict()
        job_data["job_index"] = job_doc.id
        jobs.append(job_data)
    return jobs


def get_recommendation_id_by_user_test_id(user_test_id: str) -> str | None:
    """
    Retrieve the most recent recommendation document ID for a given user_test_id.
    """
    print(f"[DEBUG] Looking for recommendation with user_test_id: {user_test_id}")

    docs = (
        db.collection("career_recommendations")
        .where("user_test_id", "==", user_test_id)
        .limit(1)
        .stream()
    )
    for doc in docs:
        print(f"[DEBUG] Found recommendation: {doc.id}")
        return doc.id
    return None


def get_profile_text_by_user(user_id: str) -> str | None:
    """
    Get the profile_text from career_recommendations for a given user_test_id.
    Returns the first match (if multiple exist).
    """
    recs = (
        db.collection("career_recommendations")
        .where("user_test_id", "==", user_id)
        .stream()
    )
    for rec in recs:
        return rec.to_dict().get("profile_text")
    return None


# -----------------------
# CareerJobMatch
# -----------------------
def add_job_match(
    recommendation_id: str,
    job_id: str,  # Use job_id as document ID for easy reference
    job_title: str,
    job_description: str,
    similarity_score: float,
    similarity_percentage: float,
    required_skills: dict,
    required_knowledge: dict,
) -> str:
    """
    Adds a job match under a career recommendation in Firestore.
    Converts job_id to string and ensures all data is JSON-serializable.
    Logs success or failure.
    """
    # Ensure recommendation_id and job_id are strings
    recommendation_id = str(recommendation_id)
    job_id = str(job_id)

    # Make sure skills and knowledge are JSON-serializable
    def serialize_dict(d):
        if not isinstance(d, dict):
            return {}
        return {k: (list(v) if isinstance(v, set) else v) for k, v in d.items()}

    required_skills = serialize_dict(required_skills)
    required_knowledge = serialize_dict(required_knowledge)

    # Reference to Firestore document
    job_ref = (
        db.collection("career_recommendations")
        .document(recommendation_id)
        .collection("job_matches")
        .document(job_id)
    )
    job_ref.set(
        {
            "job_title": job_title,
            "job_description": job_description,
            "similarity_score": similarity_score,
            "similarity_percentage": similarity_percentage,
            "required_skills": required_skills,
            "required_knowledge": required_knowledge,
        }
    )
    return job_ref.id


def get_job_matches(recommendation_id: str):
    """
    Get all job matches for a recommendation, including job_index (document ID)
    """
    jobs = []
    collection = (
        db.collection("career_recommendations")
        .document(recommendation_id)
        .collection("job_matches")
    )

    for job_doc in collection.stream():
        job_data = job_doc.to_dict()
        job_data["job_index"] = job_doc.id  # Add the document ID as job_index
        jobs.append(job_data)

    return jobs


def get_job_match_doc(user_test_id: str, job_index: str):
    """
    Finds the recommendation_id and job_match_id for this user's job match.
    """
    all_recs = (
        db.collection("career_recommendations")
        .where("user_test_id", "==", user_test_id)
        .stream()
    )
    for rec in all_recs:
        rec_id = rec.id
        job_doc = (
            db.collection("career_recommendations")
            .document(rec_id)
            .collection("job_matches")
            .document(job_index)
            .get()
        )
        if job_doc.exists:
            return rec_id, job_doc.id
    return None, None


# charts
def save_job_charts(rec_id: str, job_index: str, charts_data: dict):
    """Save chart data for a specific job in the recommendation."""
    job_ref = (
        db.collection("career_recommendations")
        .document(rec_id)
        .collection("job_matches")
        .document(job_index)
    )

    # update the document with chart data
    job_ref.update({"charts": charts_data})

    return True


def get_job_charts(rec_id: str, job_index: str):
    """Retrieve chart data for a specific job."""
    job_ref = (
        db.collection("career_recommendations")
        .document(rec_id)
        .collection("job_matches")
        .document(job_index)
    )

    job_data = job_ref.get()
    if job_data.exists:
        return job_data.to_dict().get("charts", {})
    return {}


# -----------------------
# UserSkillsKnowledge
# -----------------------
def add_user_skills_knowledge(user_id: str, skills: dict, knowledge: dict):
    """
    Add or update skills and knowledge for a user_test document.
    """
    user_ref = db.collection("user_tests").document(user_id)
    user_ref.set({"skills": skills, "knowledge": knowledge}, merge=True)


def get_user_skills_knowledge(user_id: str) -> dict:
    """
    Fetch a user's skills and knowledge from Firestore.
    Returns a dict: {"skills": {...}, "knowledge": {...}} or empty dict if not found.
    """
    doc = db.collection("user_tests").document(user_id).get()
    if doc.exists:
        data = doc.to_dict()
        return {
            "skills": data.get("skills", {}),
            "knowledge": data.get("knowledge", {}),
        }
    return {"skills": {}, "knowledge": {}}


# -----------------------
# UserJobSkillMatch
# -----------------------
def set_user_job_skill_match(
    user_id: str,
    job_match_id: str,
    skill_status: dict,
    knowledge_status: dict,
    job_title: str = None,
):
    """
    Save skill/knowledge gap analysis for a specific user and job.
    Synchronous version for compatibility with skill_gap_analysis_service.
    """
    match_ref = (
        db.collection("user_tests")
        .document(user_id)
        .collection("job_skill_matches")
        .document(job_match_id)
    )
    match_ref.set(
        {
            "job_match_id": job_match_id,
            "skill_status": skill_status,
            "knowledge_status": knowledge_status,
            "job_title": job_title,
        }
    )
    print(f"[INFO] Saved job_skill_match: user={user_id}, job={job_match_id}")


def get_user_job_skill_match(user_id: str, job_match_id: str) -> dict:
    doc = (
        db.collection("user_tests")
        .document(user_id)
        .collection("job_skill_matches")
        .document(job_match_id)
        .get()
    )
    return doc.to_dict() if doc.exists else None


def get_user_job_skill_matches(user_id: str) -> list[dict]:
    return [
        doc.to_dict()
        for doc in db.collection("user_tests")
        .document(user_id)
        .collection("job_skill_matches")
        .stream()
    ]


# -----------------------
# CareerRoadmap
# -----------------------
def create_career_roadmap(
    user_test_id: str, job_index: str, rec_id: str, topics: dict, sub_topics: dict
) -> str:
    """
    Create a career roadmap for a user and specific job.
    Document ID structure: {user_test_id}_{job_index}
    This allows easy retrieval by user + job combination.
    """
    roadmap_id = f"{user_test_id}_{job_index}"
    roadmap_ref = db.collection("career_roadmap").document(roadmap_id)
    roadmap_ref.set(
        {
            "user_test_id": user_test_id,  # reference to user_tests
            "job_index": job_index,
            "rec_id": rec_id,  # reference to career_recommendations
            "topics": topics,
            "sub_topics": sub_topics,
        }
    )
    return roadmap_ref.id


def get_career_roadmap(user_test_id: str, job_index: str) -> dict:
    """
    Fetch a specific user's career roadmap for a job.
    """
    roadmap_id = f"{user_test_id}_{job_index}"
    doc = db.collection("career_roadmap").document(roadmap_id).get()
    return doc.to_dict() if doc.exists else None
