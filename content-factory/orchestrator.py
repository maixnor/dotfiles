import os
import uuid
import datetime
from sqlalchemy import create_engine, desc
from sqlalchemy.orm import sessionmaker
from models import ContentItem, TopicIdea, Base
from blog_engine import MayaBlogEngine
from image_gen import MayaImageGenerator
from researcher import BlogResearcher

# Database setup
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://content_admin@localhost:5432/content_factory")
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

class MayaOrchestrator:
    def __init__(self):
        self.session = Session()
        self.blog_engine = MayaBlogEngine()
        self.image_gen = MayaImageGenerator()
        self.researcher = BlogResearcher()

    def step1_morning_brainstorm(self, count=10):
        """Phase 1: Generate 10 ideas and save to topic_ideas table."""
        print(f"Brainstorming {count} topics...")
        topics = self.researcher.brainstorm_topics(count=count)
        for t in topics:
            idea = TopicIdea(topic=t, status='suggested')
            self.session.add(idea)
        self.session.commit()
        return topics

    def step2_draft_selected_en(self, idea_ids):
        """Phase 2: Generate English draft + Thumbnail for selected ideas."""
        for idea_id in idea_ids:
            idea = self.session.query(TopicIdea).get(idea_id)
            if not idea or idea.status != 'suggested':
                continue
            
            print(f"Drafting English version for: {idea.topic}")
            res = self.blog_engine.generate_blog(idea.topic, "English")
            
            # Generate Image
            asset_dir = "/var/lib/content-factory/assets"
            os.makedirs(asset_dir, exist_ok=True)
            topic_group_id = uuid.uuid4()
            image_path = os.path.join(asset_dir, f"{topic_group_id}.png")
            
            # Using the headshot for consistency
            headshot_path = os.path.join(os.path.dirname(__file__), "../persona/maya.png")
            self.image_gen.generate_maya_image(res["image_prompt"], image_path, reference_image_path=headshot_path)
            
            new_item = ContentItem(
                topic_group_id=topic_group_id,
                base_topic=idea.topic,
                target_language="English",
                headline=res.get("title", idea.topic),
                markdown_content=res["markdown"],
                local_image_path=image_path,
                status="draft_en"
            )
            idea.status = 'drafted'
            self.session.add(new_item)
        
        self.session.commit()

    def step3_expand_approved_translations(self, topic_group_id):
        """Phase 3: Once English is approved, generate the other 3 languages."""
        en_version = self.session.query(ContentItem).filter(
            ContentItem.topic_group_id == topic_group_id,
            ContentItem.target_language == "English"
        ).first()
        
        if not en_version:
            return
            
        languages = ["German", "French", "Spanish"]
        for lang in languages:
            print(f"Translating {en_version.base_topic} to {lang}...")
            res = self.blog_engine.generate_blog(en_version.base_topic, lang)
            
            new_item = ContentItem(
                topic_group_id=topic_group_id,
                base_topic=en_version.base_topic,
                target_language=lang,
                headline=res.get("title", en_version.base_topic),
                markdown_content=res["markdown"],
                local_image_path=en_version.local_image_path,
                status="approved" # These are pre-approved since the English was approved
            )
            self.session.add(new_item)
        
        en_version.status = "approved"
        self.session.commit()
        
    def step4_schedule_queue(self):
        """Phase 4: Assign daily slots to approved posts."""
        approved_groups = self.session.query(ContentItem.topic_group_id).filter(
            ContentItem.status == "approved"
        ).distinct().all()
        
        # Get the latest scheduled date
        last_scheduled = self.session.query(ContentItem).filter(
            ContentItem.status == 'scheduled'
        ).order_by(desc(ContentItem.scheduled_at)).first()
        
        next_date = last_scheduled.scheduled_at + datetime.timedelta(days=1) if last_scheduled else datetime.datetime.utcnow()
        
        for (gid,) in approved_groups:
            items = self.session.query(ContentItem).filter(ContentItem.topic_group_id == gid).all()
            for item in items:
                item.status = "scheduled"
                item.scheduled_at = next_date
            next_date += datetime.timedelta(days=1)
            
        self.session.commit()

if __name__ == "__main__":
    pass
