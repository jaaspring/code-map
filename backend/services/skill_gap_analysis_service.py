from sqlalchemy.orm import Session
from models.assessment import UserSkillsKnowledge, CareerJobMatch, UserJobSkillMatch

def compute_skill_gaps_for_all_jobs(user_test_id: int, db: Session):
    """
    Loop through all jobs in the DB and compute/save skill gaps for the given user.
    """
    results = []

    # 1. Fetch all jobs
    all_jobs = db.query(CareerJobMatch).all()
    if not all_jobs:
        return {"error": "No jobs found in the database."}

    # 2. Loop through each job and compute skill gap
    for job in all_jobs:
        result = compare_and_save(user_test_id=user_test_id, job_match_id=job.job_index, db=db)
        results.append({
            "job_index": job.job_index,
            "job_title": job.job_title,
            "gap_analysis": result
        })

    return results

def compare_and_save(user_test_id: int, job_match_id: int, db: Session):
    """
    Fetch user & job data from DB, compare, save result into UserJobSkillMatch.
    """

    # Fetch user data
    user_data = db.query(UserSkillsKnowledge).filter_by(user_test_id=user_test_id).first()
    if not user_data:
        return {"error": f"No user skills/knowledge for user_test_id={user_test_id}"}

    # Fetch job data
    job_data = db.query(CareerJobMatch).filter_by(job_index=job_match_id).first()
    if not job_data:
        return {"error": f"No job match found for job_match_id={job_match_id}"}

    # Use the real DB id for UserJobSkillMatch
    job_match_id = job_data.id

    # Extract dicts
    user_skills = user_data.skills or {}
    user_knowledge = user_data.knowledge or {}
    req_skills = job_data.required_skills or {}
    req_knowledge = job_data.required_knowledge or {}

    # 4. Compare
    result = {"skills": {}, "knowledge": {}}

    # --- Skills
    for skill, req_level in req_skills.items():
        user_level = user_skills.get(skill) or "Not Provided"  # default to Not Provided
        status = "Achieved" if user_level != "Not Provided" else "Missing"
        
        result["skills"][skill] = {
            "required_level": req_level,
            "user_level": user_level,
            "status": status
        }

    # --- Knowledge
    for knowledge, req_level in req_knowledge.items():
        user_level = user_knowledge.get(knowledge) or "Not Provided"
        status = "Achieved" if user_level != "Not Provided" else "Missing"
        
        result["knowledge"][knowledge] = {
            "required_level": req_level,
            "user_level": user_level,
            "status": status
        }


    # Save to DB (insert or update)
    existing = (
        db.query(UserJobSkillMatch)
        .filter_by(user_test_id=user_test_id, job_match_id=job_match_id)
        .first()
    )

    if existing:
        existing.skill_status = result["skills"]
        existing.knowledge_status = result["knowledge"]
    else:
        entry = UserJobSkillMatch(
            user_test_id=user_test_id,
            job_match_id=job_match_id,
            skill_status=result["skills"],
            knowledge_status=result["knowledge"]
        )
        db.add(entry)

    db.commit()
    
    result["job_title"] = job_data.job_title

    return result
