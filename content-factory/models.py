from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, UUID
from sqlalchemy.orm import declarative_base, relationship
import datetime
import uuid

Base = declarative_base()

class TopicIdea(Base):
    """Phase 1: Brainstormed ideas to be selected by you."""
    __tablename__ = 'topic_ideas'
    id = Column(Integer, primary_key=True)
    topic = Column(String, nullable=False)
    source = Column(String)
    # suggested -> selected/rejected -> drafted
    status = Column(String, default='suggested') 
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class ContentItem(Base):
    """Phase 2 & 3: The actual blog posts."""
    __tablename__ = 'content_items'

    id = Column(Integer, primary_key=True)
    topic_group_id = Column(UUID(as_uuid=True), default=uuid.uuid4, nullable=False, index=True)
    base_topic = Column(String, nullable=False)
    category = Column(String, default="blog")
    target_language = Column(String, nullable=False)
    
    # Content fields
    headline = Column(String)
    markdown_content = Column(Text)
    local_image_path = Column(Text)
    
    # State management
    # draft_en -> approved_en -> scheduled -> posted
    status = Column(String, default='draft_en') 
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    scheduled_at = Column(DateTime)
    
    logs = relationship("PublicationLog", back_populates="content_item")

class PublicationLog(Base):
    __tablename__ = 'publication_log'
    id = Column(Integer, primary_key=True)
    content_item_id = Column(Integer, ForeignKey('content_items.id'))
    platform = Column(String, nullable=False) 
    platform_post_id = Column(String)
    status = Column(String, default='pending')
    published_at = Column(DateTime)
    content_item = relationship("ContentItem", back_populates="logs")