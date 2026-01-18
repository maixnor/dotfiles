import os
from google import genai
from google.genai import types
from PIL import Image
from persona import MAYA_WRITING_STYLE, MAYA_VISUAL_PROMPT
from utils import get_secret

class MayaBlogEngine:
    def __init__(self, api_key=None):
        api_key = api_key or get_secret("GEMINI_API_KEY")
        self.client = genai.Client(api_key=api_key)
        self.model_name = 'gemini-3-flash-preview'

    def generate_blog(self, topic, target_language="English"):
        """
        Generates a markdown blog post and a matching image prompt.
        Uses the Maya headshot as reference for visual consistency.
        """
        # 1. Generate Blog Content
        prompt = f"{MAYA_WRITING_STYLE}\n\nWrite a short, engaging blog post about: {topic}. \nInclude an 'Introduction', 'Cultural Insight', and 'Maya's Top 3 Tips'. \nFormat the entire response as Markdown in {target_language}."
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt
        )
        content = response.text

        # 2. Generate Image Context using Headshot as Reference
        # Path relative to the script execution
        headshot_path = os.path.join(os.path.dirname(__file__), "../persona/maya.png")
        headshot = Image.open(headshot_path)

        image_context_prompt = (
            f"You are a master art director. Look at the attached headshot of Maya. "
            f"Write a detailed Imagen 3 prompt to place this exact character (same face, same hair, same art style) "
            f"into a scene where she is {topic}. "
            "Describe the lighting, the background, and her pose while ensuring she remains 100% "
            "consistent with the attached reference image. Keep the art style: clean line art with stippled texture."
        )
        
        image_resp = self.client.models.generate_content(
            model=self.model_name,
            contents=[image_context_prompt, headshot]
        )
        action_prompt = image_resp.text.strip()
        
        # We combine her base identity with the scene-specific details from Gemini
        full_image_prompt = f"{MAYA_VISUAL_PROMPT.split('SCENE:')[0]} SCENE: {action_prompt}"

        return {
            "title": topic,
            "markdown": content,
            "image_prompt": full_image_prompt
        }