from core.database import db
from google.cloud import firestore
from google.cloud.firestore_v1 import FieldFilter


# -----------------------
# UserTest
# -----------------------
def create_user_test(data: dict, user_test_id: str = None) -> str:
    """
    Create a new user test document.
    data keys: educationLevel, cgpa, thesisTopic, major, programmingLanguages,
               courseworkExperience, skillReflection, thesisFindings, careerGoals
    Returns the new document ID.
    """
    if user_test_id:
        user_ref = db.collection("user_tests").document(user_test_id)
    else:
        user_ref = db.collection("user_tests").document()  # auto-ID
        
    data["created_at"] = firestore.SERVER_TIMESTAMP
    user_ref.set(data)
    return user_ref.id


def get_user_test(user_id: str) -> dict:
    doc = db.collection("user_tests").document(user_id).get()
    return doc.to_dict() if doc.exists else None


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


def get_job_by_index(rec_id: str, job_match_id: str):
    doc = (
        db.collection("career_recommendations")
        .document(rec_id)
        .collection("job_matches")
        .document(job_match_id)
        .get()
    )

    if not doc.exists:
        print(f"[ERROR] Job match {job_match_id} not found under rec {rec_id}")
        return None

    return doc.to_dict()


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
def save_job_charts(
    rec_id: str, job_index: str, charts_data: dict, attempt_number: int = 1
):
    job_ref = (
        db.collection("career_recommendations")
        .document(rec_id)
        .collection("job_matches")
        .document(job_index)
    )

    job_doc = job_ref.get()
    if job_doc.exists:
        existing = job_doc.to_dict().get("charts", {})
        existing[str(attempt_number)] = charts_data
        job_ref.update({"charts": existing})
    else:
        job_ref.set({"charts": {str(attempt_number): charts_data}})
    return True


def get_job_charts(rec_id: str, job_match_id: str, attempt_number: int):
    job_ref = (
        db.collection("career_recommendations")
        .document(rec_id)
        .collection("job_matches")
        .document(job_match_id)
    )

    job_data = job_ref.get()
    if job_data.exists:
        all_charts = job_data.to_dict().get("charts", {})
        return all_charts.get(str(attempt_number), {})  # charts keyed by attempt
    return {}


# attempts
def get_user_attempts(user_test_id: str) -> list[dict]:
    """
    Fetch all assessment attempts for a user_test_id from the 'users' collection.
    Returns a list of dicts, each containing attemptNumber, completedAt, status, testId, etc.
    """
    user_ref = db.collection("users").document(user_test_id)
    user_doc = user_ref.get()
    if user_doc.exists:
        data = user_doc.to_dict()
        return data.get("assessmentAttempts", [])
    return []


# -----------------------
# UserSkillsKnowledge
# -----------------------
def add_user_skills_knowledge(user_test_id: str, skills: dict, knowledge: dict):
    """
    Add or update skills and knowledge for a user_test document.
    """
    user_ref = db.collection("user_tests").document(user_test_id)
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
def set_user_job_match(
    rec_id: str,
    job_match_id: str,
    skill_status: dict,
    knowledge_status: dict,
):
    print(f"[DEBUG] set_user_job_match → rec_id={rec_id}, job_match_id={job_match_id}")

    job_ref = (
        db.collection("career_recommendations")
        .document(rec_id)
        .collection("job_matches")
        .document(str(job_match_id))
    )

    job_ref.update(
        {
            "skill_status": skill_status,
            "knowledge_status": knowledge_status,
        }
    )


def get_user_job_skill_matches(user_test_id: str) -> list[dict]:
    results = []
    try:
        # find the document in career_recommendations that has this user_test_id
        career_recs_ref = db.collection("career_recommendations")

        # query for documents where user_test_id field equals our parameter
        query = career_recs_ref.where("user_test_id", "==", user_test_id)
        matching_docs = query.stream()

        doc_ids = []
        for doc in matching_docs:
            doc_ids.append(doc.id)
            print(f"Found career_recommendations document: {doc.id}")

        if not doc_ids:
            print(f"No career_recommendations found with user_test_id: {user_test_id}")
            return []

        # use the first matching document (should only be one)
        parent_doc_id = doc_ids[0]

        # get the nested job_matches collection
        job_matches_ref = (
            db.collection("career_recommendations")
            .document(parent_doc_id)
            .collection("job_matches")
            .stream()
        )

        for doc in job_matches_ref:
            data = doc.to_dict()
            filtered = {
                "job_match_id": doc.id,
                "job_title": data.get("job_title", "N/A"),
                "skill_status": data.get("skill_status", {}),
                "knowledge_status": data.get("knowledge_status", {}),
            }
            results.append(filtered)

        print(f"Found {len(results)} job matches for user_test_id: {user_test_id}")
        return results

    except Exception as e:
        print(f"Error in get_user_job_skill_matches: {e}")
        import traceback

        traceback.print_exc()
        return []


# -----------------------
# CareerRoadmap
# -----------------------
def create_career_roadmap(
    user_test_id: str, job_match_id: str, rec_id: str, topics: dict, sub_topics: dict
) -> str:
    """
    Create a career roadmap for a user and specific job.
    Document ID structure: {user_test_id}_{job_index}
    """
    roadmap_id = f"{user_test_id}_{job_match_id}"
    roadmap_ref = db.collection("career_roadmap").document(roadmap_id)
    roadmap_ref.set(
        {
            "user_test_id": user_test_id,  # reference to user_tests
            "job_match_id": job_match_id,
            "rec_id": rec_id,  # reference to career_recommendations
            "topics": topics,
            "sub_topics": sub_topics,
        }
    )
    return roadmap_ref.id


def get_career_roadmap(user_test_id: str, job_match_id: str) -> dict:
    """
    Fetch a specific user's career roadmap for a job.
    """
    roadmap_id = f"{user_test_id}_{job_match_id}"
    doc = db.collection("career_roadmap").document(roadmap_id).get()
    return doc.to_dict() if doc.exists else None
