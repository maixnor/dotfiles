from models import ContentItem, Session, TopicIdea
from sqlalchemy import desc
import datetime
import uuid

def get_pending_drafts():
    """
    Returns items waiting for approval, grouped by topic.
    Suitable for a Windmill table or list view.
    """
    session = Session()
    drafts = session.query(ContentItem).filter(ContentItem.status.like('draft%')).all()
    
    output = []
    for d in drafts:
        output.append({
            "id": d.id,
            "group_id": str(d.topic_group_id),
            "topic": d.base_topic,
            "language": d.target_language,
            "headline": d.headline,
            "status": d.status
        })
    session.close()
    return output

def approve_item(item_id, edited_headline=None):
    """
    Approves a single item and schedules it.
    """
    session = Session()
    item = session.query(ContentItem).get(item_id)
    if not item:
        return {"error": "Item not found"}
    
    if edited_headline:
        item.headline = edited_headline
        
    item.status = "scheduled"
    
    # Simple scheduler: find last scheduled and add 24h
    last = session.query(ContentItem).filter(ContentItem.status == 'scheduled').order_by(desc(ContentItem.scheduled_at)).first()
    if last and last.scheduled_at:
        item.scheduled_at = last.scheduled_at + datetime.timedelta(days=1)
    else:
        item.scheduled_at = datetime.datetime.utcnow() + datetime.timedelta(hours=1)
        
    session.commit()
    res = {"status": "success", "scheduled_at": item.scheduled_at.isoformat()}
    session.close()
    return res

def reject_item(item_id):
    """
    Rejects an item.
    """
    session = Session()
    item = session.query(ContentItem).get(item_id)
    if item:
        item.status = "rejected"
        session.commit()
    session.close()
    return {"status": "rejected"}
