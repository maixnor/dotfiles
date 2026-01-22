import os
from google import genai
from persona import MAYA_WRITING_STYLE, MAYA_VISUAL_PROMPT
from utils import get_secret

class BlogResearcher:
    """
    Identifies topics for Maya's blog using Gemini.
    """
    
    def __init__(self, api_key=None):
        api_key = api_key or get_secret("GEMINI_API_KEY")
        self.client = genai.Client(api_key=api_key)
        self.model_name = 'gemini-3-flash-preview'

    def brainstorm_topics(self, count=5):
        """
        Original Phase 1: Creative topics based on Maya's expat persona.
        """
        prompt = f"""
        {MAYA_WRITING_STYLE}
        Based on your interests (Foodie, History Buff, Vinyl/Jazz enthusiast, Expat life), 
        brainstorm {count} unique and engaging blog post topics.
        Return the topics as a simple bulleted list. 
        Each topic should be a catchy headline.
        """
        response = self.client.models.generate_content(model=self.model_name, contents=prompt)
        return [line.strip('- ').strip() for line in response.text.strip().split('\n') if line.strip()][:count]

    def analyze_community_problems(self, community_data):
        """
        New Lead-Gen Mode: Extracts topics from real-world community friction.
        """
        context = "\n---\n".join([f"Source: {p['source']}\nTitle: {p['title']}\n{p['content'][:300]}" for p in community_data])
        
        prompt = f"""
        {MAYA_WRITING_STYLE}
        Analyze these language learning community posts to find 'Linguistic Friction'.
        Identify 5 high-value topics suitable for 'School vs. Native' cards or 'Cheat Sheets'.

        COMMUNITY DATA:
        {context}

        Return only a bulleted list of catchy headlines.
        """
        response = self.client.models.generate_content(model=self.model_name, contents=prompt)
        return [line.strip('- ').strip() for line in response.text.strip().split('\n') if line.strip()]