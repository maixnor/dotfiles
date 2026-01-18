import os
import shutil
import datetime
from models import ContentItem, PublicationLog, Session
import httpx
from utils import get_secret

# Where the blog lives
BLOG_EXPORT_ROOT = "/var/www/maixnor.com/maya-blog"

def publish_to_blog(item):
    """
    Exports the post to the static site directory.
    """
    print(f"Publishing {item.id} to Blog...")
    date_str = item.scheduled_at.strftime("%Y-%m-%d")
    lang_dir = os.path.join(BLOG_EXPORT_ROOT, date_str, item.target_language.lower())
    os.makedirs(lang_dir, exist_ok=True)
    
    md_path = os.path.join(lang_dir, "index.md")
    with open(md_path, "w") as f:
        f.write(f"# {item.headline}\n\n")
        if item.local_image_path:
            f.write(f"![Maya Illustration](maya.png)\n\n")
        f.write(item.markdown_content or "")
        
        if item.left_column_text:
            f.write("\n\n## Comparison\n")
            f.write(f"**School:** {item.left_column_text}\n")
            f.write(f"**Native:** {item.right_column_text}\n")

    if item.local_image_path and os.path.exists(item.local_image_path):
        shutil.copy(item.local_image_path, os.path.join(lang_dir, "maya.png"))
    
    return True

def publish_to_mastodon(item):
    """
    Publishes the post to Mastodon using the API.
    """
    token = get_secret("MASTODON_TOKEN", "MASTODON_TOKEN_FILE")
    if not token:
        print("Skipping Mastodon: No token found.")
        return False
    
    # Implementation using httpx to post status
    # ...
    return True

def publish_due_items():

    """

    Main loop for due items.

    """

    session = Session()

    now = datetime.datetime.utcnow()

    

    due = session.query(ContentItem).filter(

        ContentItem.status == 'scheduled',

        ContentItem.scheduled_at <= now

    ).all()

    

    for item in due:

        # Publish to all enabled targets

        success = publish_to_blog(item)

        

        if success:

            item.status = "posted"

            # Log it

            log = PublicationLog(

                content_item_id=item.id,

                platform="blog",

                status="published",

                published_at=datetime.datetime.utcnow()

            )

            session.add(log)

            

    session.commit()

    session.close()



if __name__ == "__main__":

    publish_due_items()
