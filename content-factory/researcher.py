import os
from google import genai
from persona import MAYA_WRITING_STYLE, MAYA_VISUAL_PROMPT
from utils import get_secret

class BlogResearcher:
    """
    Identifies topics for Maya's blog using Gemini 3.
    """
    
    def __init__(self, api_key=None):
        api_key = api_key or get_secret("GEMINI_API_KEY")
        self.client = genai.Client(api_key=api_key)
        self.model_name = 'gemini-3-flash-preview'

    def brainstorm_topics(self, count=5):
        """
        Uses Maya's persona to brainstorm interesting blog post topics.
        """
        prompt = f"""
        {MAYA_WRITING_STYLE}
        
        Based on your interests (Foodie, History Buff, Vinyl/Jazz enthusiast, Expat life), 
        brainstorm {count} unique and engaging blog post topics that would help people 
        learning a new language and culture. 
        
        Return the topics as a simple bulleted list. 
        Each topic should be a catchy headline.
        """
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt
        )
        topics = [line.strip('- ').strip() for line in response.text.strip().split('\n') if line.strip()]
        return topics[:count]

