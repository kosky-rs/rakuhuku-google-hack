"""Firebase Helper - Safe client retrieval and initialization checks"""
import logging
from typing import Optional

import firebase_admin
from firebase_admin import firestore

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
