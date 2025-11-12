from core.database import db


# -----------------------
# UserTest
# -----------------------
def create_user_test(data: dict) -> str:
    """
    Create a new user test document.
    data keys: educationLevel, cgpa, thesisTopic, major, programmingLanguages,
               courseworkExperience, skillReflection, thesisFindings, careerGoals
    Returns the new document ID.
    """
    user_ref = db.collection("user_tests").document()  # auto-ID
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
    options=None,
    answer=None,
    difficulty=None,
    question_type=None,
) -> str:
    question_ref = db.collection("generated_questions").document()
    question_ref.set(
        {
            "user_test_id": user_id,
            "question_text": question_text,
            "options": options or [],
            "answer": answer,
            "difficulty": difficulty,
            "question_type": question_type,
        }
    )
    return question_ref.id


def get_generated_questions(user_id: str):
    return [
        # q.to_dict()
        {**q.to_dict(), "id": q.id}  # include Firestore doc ID
        for q in db.collection("generated_questions")
        .where("user_test_id", "==", user_id)
        .stream()
    ]


# -----------------------
# FollowUpAnswers
# -----------------------
def add_follow_up_answer(user_id: str, question_id: str, selected_option: str) -> str:
    """
    Add a follow-up answer document.
    """
    answer_ref = db.collection("follow_up_answers").document()
    answer_ref.set(
        {
            "user_test_id": user_id,
            "question_id": question_id,
            "selected_option": selected_option,
        }
    )
    return answer_ref.id


def get_follow_up_answers_by_user(user_id: str):
    return [
        doc.to_dict()
        for doc in db.collection("follow_up_answers")
        .where("user_test_id", "==", user_id)
        .stream()
    ]


# -----------------------
# CareerRecommendation
# -----------------------
def add_career_recommendation(user_id: str, profile_text: str) -> str:
    rec_ref = db.collection("career_recommendations").document()
    rec_ref.set({"user_test_id": user_id, "profile_text": profile_text})
    return rec_ref.id


def get_all_jobs():
    """
    Fetch all jobs across all recommendations.
    """
    jobs = []
    recs = db.collection("career_recommendations").stream()
    for rec in recs:
        collection = (
            db.collection("career_recommendations")
            .document(rec.id)
            .collection("job_matches")
        )
        for job_doc in collection.stream():
            job_data = job_doc.to_dict()
            job_data["job_index"] = job_doc.id
            jobs.append(job_data)
    return jobs


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
    Retrieve the recommendation document ID for a given user_test_id.
    Returns None if not found.
    """
    docs = (
        db.collection("career_recommendations")
        .where("user_test_id", "==", user_test_id)
        .limit(1)
        .stream()
    )
    for doc in docs:
        return doc.id
    return None


def get_job_by_index(job_index: str):
    """
    Fetch a job across all career recommendations by its job_index.
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
    return [
        job.to_dict()
        for job in db.collection("career_recommendations")
        .document(recommendation_id)
        .collection("job_matches")
        .stream()
    ]


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


def add_report_chart(
    recommendation_id: str,
    job_id: str,
    radar_chart_base64: str,
    bar_chart_base64: str,
) -> str:
    """
    Adds or updates both radar and bar charts for a job match under a career recommendation.
    """
    recommendation_id = str(recommendation_id)
    job_id = str(job_id)

    chart_ref = (
        db.collection("career_recommendations")
        .document(recommendation_id)
        .collection("job_matches")
        .document(job_id)
    )

    chart_ref.set(
        {"charts": {"radar_chart": radar_chart_base64, "bar_chart": bar_chart_base64}},
        merge=True,  # preserves existing fields like skills, job_title, etc.
    )

    return chart_ref.id


# -----------------------
# UserSkillsKnowledge
# -----------------------
def add_user_skills(user_id: str, skills: dict, knowledge: dict):
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
