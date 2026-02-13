"""Firebase Helper - Safe client retrieval and initialization checks"""
import base64
import logging
import uuid
from typing import Optional

import firebase_admin
from firebase_admin import firestore, storage

logger = logging.getLogger(__name__)


def get_firestore_client():
    """
    Get Firestore client safely

    Returns:
        firestore.Client: Firestore client instance

    Raises:
        RuntimeError: If Firebase Admin SDK is not initialized
    """
    if not firebase_admin._apps:
        raise RuntimeError(
            "Firebase Admin SDK not initialized. "
            "Make sure the application starts through main.py with lifespan initialization."
        )

    try:
        return firestore.client()
    except Exception as e:
        logger.error(f"Failed to get Firestore client: {e}")
        raise RuntimeError(f"Failed to get Firestore client: {e}")


def is_firebase_initialized() -> bool:
    """
    Check if Firebase Admin SDK is initialized

    Returns:
        bool: True if initialized, False otherwise
    """
    return len(firebase_admin._apps) > 0


def get_firebase_app():
    """
    Get Firebase Admin SDK app instance

    Returns:
        firebase_admin.App: Firebase app instance

    Raises:
        RuntimeError: If Firebase Admin SDK is not initialized
    """
    if not firebase_admin._apps:
        raise RuntimeError("Firebase Admin SDK not initialized")

    return firebase_admin.get_app()


def upload_base64_image(base64_data: str, user_id: str, prefix: str = "closet_images") -> Optional[str]:
    """
    Base64画像をFirebase Storageにアップロードし、ダウンロードURLを返す

    Args:
        base64_data: base64エンコードされた画像データ
        user_id: ユーザーID
        prefix: Storageのパスプレフィックス

    Returns:
        Firebase Storage ダウンロードURL。失敗時はNone
    """
    if not base64_data:
        return None

    try:
        from urllib.parse import quote

        if "," in base64_data:
            base64_data = base64_data.split(",", 1)[1]

        image_bytes = base64.b64decode(base64_data)

        bucket = storage.bucket()
        filename = f"{prefix}/{user_id}/{uuid.uuid4().hex}.jpg"
        blob = bucket.blob(filename)

        download_token = uuid.uuid4().hex
        blob.metadata = {"firebaseStorageDownloadTokens": download_token}
        blob.upload_from_string(image_bytes, content_type="image/jpeg")

        encoded_path = quote(filename, safe="")
        return (
            f"https://firebasestorage.googleapis.com/v0/b/{bucket.name}"
            f"/o/{encoded_path}?alt=media&token={download_token}"
        )
    except Exception as e:
        logger.error(f"Failed to upload base64 image to Storage: {e}")
        return None
