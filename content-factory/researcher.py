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

            

            TASK:

            Based on your interests (Foodie, History Buff, Vinyl/Jazz enthusiast, Expat life), 

            brainstorm {count} unique and engaging blog post topics.

            

            CRITICAL INSTRUCTIONS:

            - Return ONLY a list of headlines.

            - NO introductory text like "Hey there!" or "Here are some ideas".

            - NO markdown formatting like bolding or bullets.

            - One topic per line.

            """

            response = self.client.models.generate_content(model=self.model_name, contents=prompt)

            # Filter out empty lines and anything that looks like a preamble

            lines = [l.strip() for l in response.text.strip().split('\n') if l.strip()]

            return [l.lstrip('*- ').strip() for l in lines if len(l) > 10 and not l.lower().startswith(('hey', 'here are', 'i am', 'maya here'))]

    

        def analyze_community_problems(self, community_data):

            """

            New Lead-Gen Mode: Extracts topics from real-world community friction.

            """

            context = "\n---\n".join([f"Source: {p['source']}\nTitle: {p['title']}\n{p['content'][:300]}" for p in community_data])

            

            prompt = f"""

            {MAYA_WRITING_STYLE}

            

            TASK:

            Analyze these language learning community posts to find 'Linguistic Friction'.

            Identify 5 high-value topics suitable for 'School vs. Native' cards or 'Cheat Sheets'.

    

            COMMUNITY DATA:

            {context}

    

            CRITICAL INSTRUCTIONS:

            - Return ONLY the headlines.

            - NO preamble, NO conversation, NO intro.

            - One topic per line.

            """

            response = self.client.models.generate_content(model=self.model_name, contents=prompt)

            lines = [l.strip() for l in response.text.strip().split('\n') if l.strip()]

            return [l.lstrip('*- ').strip() for l in lines if len(l) > 10 and not l.lower().startswith(('hey', 'here are', 'i am', 'maya here'))]

    