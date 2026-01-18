import os
import sys
from orchestrator import MayaOrchestrator
from publisher import publish_due_items

# --- Step 1: Brainstorm ---
def brainstorm(count: int = 10):
    """
    Morning Brainstorm: Generates topic ideas.
    """
    orc = MayaOrchestrator()
    topics = orc.step1_morning_brainstorm(count=count)
    return {"status": "success", "topics_found": len(topics)}

# --- Step 2: Draft English ---
def draft_selected(idea_ids: list[int]):
    """
    Draft Selected: Generates EN content and thumbnails for chosen IDs.
    """
    orc = MayaOrchestrator()
    orc.step2_draft_selected_en(idea_ids)
    return {"status": "success", "message": f"Drafted {len(idea_ids)} topics."}

# --- Step 3: Approve & Translate ---
def approve_and_translate(topic_group_id: str):
    """
    Approve & Translate: Expands an English draft into all 4 languages.
    """
    orc = MayaOrchestrator()
    orc.step3_expand_approved_translations(topic_group_id)
    orc.step4_schedule_queue() # Automatically add to queue after translation
    return {"status": "success", "group": topic_group_id}

# --- Step 4: Publish (The Cron Job) ---
def publish_scheduled():
    """
    The Publisher: Runs daily (or twice daily) to push scheduled posts live.
    """
    print("Checking for due posts...")
    publish_due_items()
    return {"status": "done"}
