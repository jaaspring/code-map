import os
from typing import List, Dict, Any
import hashlib
from dotenv import load_dotenv
from pinecone import Pinecone, ServerlessSpec

load_dotenv()


class PineconeService:
    def __init__(self, index_name: str = "code-map", dimension: int = 384):
        """
        Initialize Pinecone service.
        Default dimension is for all-MiniLM-L6-v2 model
        """
        self.api_key = os.getenv("PINECONE_API_KEY")
        if not self.api_key:
            raise ValueError("PINECONE_API_KEY not found in .env")

        self.pc = Pinecone(api_key=self.api_key)
        self.index_name = index_name
        self.dimension = dimension

        # initialize or connect to index
        self._init_index()

    def _init_index(self):
        """Initialize Pinecone index if it doesn't exist"""
        if self.index_name not in self.pc.list_indexes().names():
            print(f"Creating new index: {self.index_name}")
            self.pc.create_index(
                name=self.index_name,
                dimension=self.dimension,
                metric="cosine",
                spec=ServerlessSpec(cloud="aws", region="us-east-1"),
            )
            print(f"✓ Index {self.index_name} created successfully")

        self.index = self.pc.Index(self.index_name)
        print(f"✓ Connected to index: {self.index_name}")

    def _generate_vector_id(self, content: str, prefix: str = "") -> str:
        """Generate stable vector ID from content"""
        hash_input = f"{prefix}_{content}".encode()
        return hashlib.md5(hash_input).hexdigest()

    def upsert_user(
        self, user_test_id: str, embedding: List[float], metadata: Dict[str, Any]
    ) -> None:
        """
        Upsert user embedding to Pinecone
        """
        vector_id = self._generate_vector_id(user_test_id, prefix="user")

        # Ensure metadata is clean
        clean_metadata = {
            "type": "user",
            "user_test_id": str(user_test_id),
            **{k: str(v) if v is not None else "" for k, v in metadata.items()},
        }

        vector = {"id": vector_id, "values": embedding, "metadata": clean_metadata}

        self.index.upsert(vectors=[vector], namespace="users")
        print(f"✓ User {user_test_id} upserted to Pinecone")

    def upsert_job(
        self, job_id: str, embedding: List[float], metadata: Dict[str, Any]
    ) -> None:
        """
        Upsert job embedding to Pinecone
        """
        vector_id = self._generate_vector_id(job_id, prefix="job")

        clean_metadata = {
            "type": "job",
            "job_id": str(job_id),
            **{k: str(v) if v is not None else "" for k, v in metadata.items()},
        }

        vector = {"id": vector_id, "values": embedding, "metadata": clean_metadata}

        self.index.upsert(vectors=[vector], namespace="jobs")
        print(f"✓ Job {job_id} upserted to Pinecone")

    def query_similar_jobs(
        self, user_embedding: List[float], top_k: int = 5
    ) -> List[Dict]:
        """
        Query similar jobs based on user embedding
        """
        try:
            response = self.index.query(
                vector=user_embedding,
                top_k=top_k,
                include_metadata=True,
                filter={"type": {"$eq": "job"}},
                namespace="jobs",
            )

            if not hasattr(response, "matches"):
                print(f"Warning: No matches found in response")
                return []

            results = []
            for match in response.matches:
                results.append(
                    {"id": match.id, "score": match.score, "metadata": match.metadata}
                )

            print(f"✓ Found {len(results)} job matches")
            return results

        except Exception as e:
            print(f"✗ Error querying Pinecone for jobs: {e}")
            return []

    def query_similar_users(
        self, user_embedding: List[float], top_k: int = 5
    ) -> List[Dict]:
        """
        Query similar users based on user embedding
        """
        try:
            response = self.index.query(
                vector=user_embedding,
                top_k=top_k,
                include_metadata=True,
                filter={"type": {"$eq": "user"}},
                namespace="users",
            )

            if not hasattr(response, "matches"):
                print(f"Warning: No user matches found")
                return []

            results = []
            for match in response.matches:
                results.append(
                    {"id": match.id, "score": match.score, "metadata": match.metadata}
                )

            print(f"✓ Found {len(results)} user matches")
            return results

        except Exception as e:
            print(f"✗ Error querying Pinecone for users: {e}")
            return []
