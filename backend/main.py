from fastapi import FastAPI
from routes import assessment_routes, user_routes
from core.model_loader import initialize_ai_models, is_initialized

# Create FastAPI app
app = FastAPI(title="CodeMap API")


# Health check endpoint
@app.get("/health")
async def health_check():
    if is_initialized():
        return {"status": "ready", "message": "Server is running"}
    else:
        return {"status": "starting", "message": "Server is initializing"}


# Run initialization when FastAPI starts
@app.on_event("startup")
async def on_startup():
    # Initialize AI models and load job data
    initialize_ai_models()  # This will load everything
    print("✓ Server startup complete - Ready for requests!")


# Register routers
app.include_router(assessment_routes.router)
app.include_router(user_routes.router)
