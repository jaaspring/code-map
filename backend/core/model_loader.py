import glob
import os
import pickle
import pandas as pd
import torch
from transformers import AutoTokenizer, AutoModel
from typing import List

_tokenizer = None
_model = None
df = pd.DataFrame()
job_embeddings = []


def initialize_ai_models():
    """Initialize HuggingFace model and load job embeddings."""
    global _tokenizer, _model, df, job_embeddings

    print("Initializing AI models...")
    hf_model_name = "sentence-transformers/all-MiniLM-L6-v2"
    _tokenizer = AutoTokenizer.from_pretrained(hf_model_name)
    _model = AutoModel.from_pretrained(hf_model_name)
    print("✓ HuggingFace model loaded")

    folder_path = "data"
    csv_files = glob.glob(f"{folder_path}/*.csv")
    dfs = []

    for file in csv_files:
        try:
            df_temp = pd.read_csv(file)
            if not df_temp.empty:
                dfs.append(df_temp)
        except pd.errors.EmptyDataError:
            print(f"Skipping empty file: {file}")

    if dfs:
        df = pd.concat(dfs, ignore_index=True)
        print(f"✓ Loaded {len(df)} job records")
        embeddings_file = os.path.join(folder_path, "job_embeddings.pkl")

        if os.path.exists(embeddings_file):
            try:
                with open(embeddings_file, "rb") as f:
                    job_embeddings = pickle.load(f)
                print(f"✓ Loaded {len(job_embeddings)} pre-generated embeddings")
            except Exception as e:
                print(f"Error loading embeddings: {e}. Regenerating...")
                job_embeddings = _generate_and_save_embeddings(df, embeddings_file)
        else:
            job_embeddings = _generate_and_save_embeddings(df, embeddings_file)
    else:
        print("No valid data found in CSV files.")
        df = pd.DataFrame()


def _generate_and_save_embeddings(df, embeddings_file):
    print("Generating embeddings for all job descriptions...")
    job_descriptions = df["Full Job Description"].astype(str)
    embeddings = [get_embeddings(text) for text in job_descriptions]

    try:
        with open(embeddings_file, "wb") as f:
            pickle.dump(embeddings, f)
        print(f"✓ Saved {len(embeddings)} embeddings to {embeddings_file}")
    except Exception as e:
        print(f"Error saving embeddings: {e}")
    return embeddings


def _ensure_models_loaded():
    if _tokenizer is None or _model is None:
        raise Exception("AI models not initialized. Call initialize_ai_models() first.")


def get_embeddings(text: str):
    _ensure_models_loaded()
    inputs = _tokenizer(text, return_tensors="pt", truncation=True, padding=True)
    with torch.no_grad():
        outputs = _model(**inputs)
    emb = outputs.last_hidden_state.mean(dim=1)
    return emb.squeeze(0).cpu().numpy().tolist()


def is_initialized() -> bool:
    return _tokenizer is not None and _model is not None and not df.empty
