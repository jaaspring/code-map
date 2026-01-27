from fastapi import APIRouter, HTTPException
from services.user_service import deactivate_user

router = APIRouter()

@router.delete("/users/{user_id}")
def delete_user(user_id: str):
    """
    Deactivate user and delete all related assessment data.
    """
    try:
        result = deactivate_user(user_id)
        return result
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Failed to deactivate user: {str(e)}")
