import os
from sqlalchemy import create_engine, desc
from sqlalchemy.orm import sessionmaker
from models import ContentItem, PublicationLog
import datetime

# Database setup
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://content_factory@localhost:5432/content_factory")
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

def list_draft_groups():
    """
    Groups drafts by topic_group_id so you can approve all 4 languages at once.
    """
    session = Session()
    # Get all drafts
    drafts = session.query(ContentItem).filter(ContentItem.status == 'draft').order_by(desc(ContentItem.created_at)).all()
    
    groups = {}
    for d in drafts:
        gid = str(d.topic_group_id)
        if gid not in groups:
            groups[gid] = {
                "topic": d.base_topic,
                "created_at": d.created_at.isoformat(),
                "image_path": d.local_image_path,
                "languages": {}
            }
        groups[gid]["languages"][d.target_language] = {
            "id": d.id,
            "headline": d.headline,
            "content": d.markdown_content
        }
    
    session.close()
    return list(groups.values())

def approve_topic_group(topic_group_id, start_date=None):
    """
    Approves all language versions for a topic and schedules them.
    If no start_date is provided, it defaults to the next available 24h slot.
    """
    session = Session()
    items = session.query(ContentItem).filter(ContentItem.topic_group_id == topic_group_id).all()
    
    if not items:
        return False

    # Simple scheduling: 1 topic per day
    if not start_date:
        last_scheduled = session.query(ContentItem).filter(ContentItem.status == 'scheduled').order_by(desc(ContentItem.scheduled_at)).first()
        if last_scheduled and last_scheduled.scheduled_at:
            start_date = last_scheduled.scheduled_at + datetime.timedelta(days=1)
        else:
            start_date = datetime.datetime.utcnow() + datetime.timedelta(days=1)

    for item in items:
        item.status = 'scheduled'
        item.scheduled_at = start_date
        
        # Initialize publication logs for platforms
        # You can add more platforms here later
        for platform in ["blog", "mastodon"]: 
            log = PublicationLog(
                content_item_id=item.id,
                platform=platform,
                status='pending'
            )
            session.add(log)
            
    session.commit()
    session.close()
    return True

if __name__ == "__main__":
    # print(list_draft_groups())
    pass
