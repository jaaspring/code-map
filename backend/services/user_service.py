from core.database import db
from models.firestore_models import (
    get_user_attempts,
    delete_document,
    delete_documents_by_query,
    delete_career_recommendation_with_subcollections,
)

def deactivate_user(user_id: str):
    """
    Deactivates a user and deletes all associated assessment data.
    """
    print(f"[INFO] Starting deactivation for user: {user_id}")
    
    # 1. Get assessment attempts to find test IDs
    # Direct fetch to debug
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()
    
    if not user_doc.exists:
        print(f"[ERROR] User {user_id} not found in users collection.")
        return {"error": "User not found"}
        
    user_data = user_doc.to_dict()
    print(f"[DEBUG] User data keys: {list(user_data.keys())}")
    
    assessment_attempts = user_data.get("assessmentAttempts", [])
    print(f"[DEBUG] Raw assessmentAttempts type: {type(assessment_attempts)}")
    print(f"[DEBUG] Raw assessmentAttempts value: {assessment_attempts}")
    
    if not assessment_attempts:
         # Fallback or check if 'testIds' exists as seen in other files
         print(f"[DEBUG] No assessmentAttempts found. Checking 'testIds'...")
         test_ids_from_field = user_data.get("testIds", [])
         print(f"[DEBUG] testIds field: {test_ids_from_field}")

    test_ids = []
    # logic for extraction
    if isinstance(assessment_attempts, list):
        for attempt in assessment_attempts:
            if isinstance(attempt, dict):
                test_id = attempt.get("testId")
                if test_id:
                    test_ids.append(test_id)
            elif isinstance(attempt, str):
                 # In case it's a list of strings
                 test_ids.append(attempt)
    elif isinstance(assessment_attempts, dict):
        # Handle case where it might be a single dict instead of list
        test_id = assessment_attempts.get("testId")
        if test_id:
            test_ids.append(test_id)
            
    # Also check 'testIds' field just in case
    test_ids_list = user_data.get("testIds", [])
    if isinstance(test_ids_list, list):
        for tid in test_ids_list:
            if isinstance(tid, str) and tid not in test_ids:
                test_ids.append(tid)

    # Remove duplicates just in case
    test_ids = list(set(test_ids))
    print(f"[INFO] Found test IDs to clean up: {test_ids}")

    # 2. Delete data for each test ID
    for test_id in test_ids:
        print(f"[INFO] Cleaning up data for test ID: {test_id}")
        
        # user_tests
        delete_document("user_tests", test_id)
        
        # generated_questions (user_test_id)
        delete_documents_by_query("generated_questions", "user_test_id", test_id)
        
        # follow_up_answers (user_test_id)
        delete_documents_by_query("follow_up_answers", "user_test_id", test_id)
        
        # career_roadmap (user_test_id)
        delete_documents_by_query("career_roadmap", "user_test_id", test_id)
        
        # career_recommendations (user_test_id) - includes subcollections
        delete_career_recommendation_with_subcollections(test_id)

    # 3. Delete the user document itself
    print(f"[INFO] Deleting user document: {user_id}")
    delete_document("users", user_id)
    
    return {"message": f"User {user_id} and all related assessment data have been deleted."}
