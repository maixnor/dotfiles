import os
import shutil
import datetime
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import ContentItem, PublicationLog

# Database setup
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://content_factory@localhost:5432/content_factory")
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

# Where the blog lives
BLOG_EXPORT_ROOT = "/var/www/maixnor.com/maya-blog"

def publish_due_items():
    """
    Checks for items that are 'scheduled' and whose time has come.
    """
    session = Session()
    now = datetime.datetime.utcnow()
    
    due_items = session.query(ContentItem).filter(
        ContentItem.status == 'scheduled',
        ContentItem.scheduled_at <= now
    ).all()
    
    if not due_items:
        print("No items due for publication.")
        return

    for item in due_items:
        print(f"Publishing item {item.id} ({item.target_language})...")
        
        # 1. Create directory for this post
        # Path: /var/www/.../maya-blog/2026-01-17/english/
        date_str = item.scheduled_at.strftime("%Y-%m-%d")
        lang_dir = os.path.join(BLOG_EXPORT_ROOT, date_str, item.target_language.lower())
        os.makedirs(lang_dir, exist_ok=True)
        
        # 2. Export Markdown
        md_path = os.path.join(lang_dir, "index.md")
        with open(md_path, "w") as f:
            f.write(f"# {item.headline}\n\n")
            f.write(f"![Maya Illustration](maya.png)\n\n")
            f.write(item.markdown_content)
        
        # 3. Copy Image
        if item.local_image_path and os.path.exists(item.local_image_path):
            shutil.copy(item.local_image_path, os.path.join(lang_dir, "maya.png"))
        
        # 4. Update status
        item.status = 'posted'
        
        # Update logs
        logs = session.query(PublicationLog).filter(PublicationLog.content_item_id == item.id).all()
        for log in logs:
            log.status = 'published'
            log.published_at = datetime.datetime.utcnow()

    session.commit()
    session.close()

if __name__ == "__main__":
    publish_due_items()
