import os
import sys
import uuid
from orchestrator import MayaOrchestrator
from publisher import publish_due_items
from models import TopicIdea, ContentItem

# --- Data Getters for UI ---

def get_suggested_ideas():
    """
    Returns all ideas in 'suggested' state for the Idea Inbox.
    """
    orc = MayaOrchestrator()
    ideas = orc.session.query(TopicIdea).filter(TopicIdea.status == 'suggested').order_by(TopicIdea.created_at.desc()).all()
    return [
        {
            "id": i.id,
            "topic": i.topic,
            "source": i.source or "brainstorm",
            "created_at": i.created_at.isoformat()
        } for i in ideas
    ]

def get_content_items(status="draft_en"):
    """
    Returns content items filtered by status (e.g., 'draft_en', 'approved', 'scheduled').
    """
    orc = MayaOrchestrator()
    items = orc.session.query(ContentItem).filter(ContentItem.status == status).order_by(ContentItem.created_at.desc()).all()
    return [
        {
            "id": i.id,
            "topic_group_id": str(i.topic_group_id),
            "base_topic": i.base_topic,
            "target_language": i.target_language,
            "headline": i.headline,
            "status": i.status,
            "image_path": i.local_image_path
        } for i in items
    ]

def get_preview(topic_group_id: str):
    """
    Returns a full preview of the English version for a specific group.
    """
    orc = MayaOrchestrator()
    item = orc.session.query(ContentItem).filter(
        ContentItem.topic_group_id == uuid.UUID(topic_group_id),
        ContentItem.target_language == "English"
    ).first()
    
    if not item:
        return {"error": "Not found"}
        
    return {
        "headline": item.headline,
        "content": item.markdown_content,
        "image_path": item.local_image_path,
        "topic": item.base_topic
    }

# --- Actions ---

def run_discovery(subreddits=None):
    """
    Triggers the lead-gen discovery phase.
    """
    orc = MayaOrchestrator()
    topics = orc.discovery_phase(subreddits=subreddits) if subreddits else orc.discovery_phase()
    return {"status": "success", "topics_found": len(topics)}

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
    # Convert string to UUID for the orchestrator
    gid = uuid.UUID(topic_group_id)
    orc.step3_expand_approved_translations(gid)
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
