#!/usr/bin/env python3
"""Clear daily recommendation cache for testing"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import sys

def init_firebase():
    """Initialize Firebase Admin SDK"""
    if not firebase_admin._apps:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)

def clear_daily_cache(user_id: str = "demo_user"):
    """
    Clear today's recommendation cache

    Args:
        user_id: User ID (default: demo_user)
    """
    db = firestore.client()
    today = datetime.now().date().isoformat()

    print(f"Clearing cache for user: {user_id}")
    print(f"Date: {today}")

    # Delete daily_recommendations cache
    cache_ref = db.collection("users").document(user_id).collection("daily_recommendations").document(today)

    cache_doc = cache_ref.get()
    if cache_doc.exists:
        cache_ref.delete()
        print(f"✅ Deleted cached recommendations for {today}")
    else:
        print(f"ℹ️  No cache found for {today}")

    # Reset tier usage (optional - to allow regeneration)
    tier_ref = db.collection("users").document(user_id).collection("tier_usage").document("current")
    tier_doc = tier_ref.get()

    if tier_doc.exists:
        tier_ref.update({
            "today_date": today,
            "today_generations": 0,
        })
        print(f"✅ Reset tier usage counter")
    else:
        print(f"ℹ️  No tier usage found")

    print("\n✨ Cache cleared! Next request will generate fresh recommendations.")

if __name__ == "__main__":
    try:
        init_firebase()

        # Get user_id from command line args if provided
        user_id = sys.argv[1] if len(sys.argv) > 1 else "demo_user"

        clear_daily_cache(user_id)

    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
