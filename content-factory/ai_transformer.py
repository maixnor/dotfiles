from google import genai
from utils import get_secret
from persona import MAYA_WRITING_STYLE
import json

class MayaAITransformer:
    def __init__(self, api_key=None):
        api_key = api_key or get_secret("GEMINI_API_KEY", "GEMINI_API_KEY_FILE")
        self.client = genai.Client(api_key=api_key)
        self.model_name = 'gemini-3-flash-preview'

    def transform_to_comparison(self, raw_text):
        """
        Takes raw scraped text and extracts "School" vs "Native" comparison points.
        """
        prompt = f"""
        {MAYA_WRITING_STYLE}
        
        You are an expert at finding the difference between how languages are taught in school 
        and how they are actually spoken on the street.
        
        Look at the following text and extract 3-5 comparison points.
        For each point, provide a "School/Formal" version and a "Native/Slang" version.
        
        TEXT:
        {raw_text}
        
        RETURN ONLY A JSON OBJECT with this structure:
        {{
            "headline": "A catchy title for the card",
            "comparisons": [
                {{"school": "phrase", "native": "slang phrase", "explanation": "why?"}},
                ...
            ],
            "caption": "An engaging social media caption with emojis"
        }}
        """
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt
        )
        
        # Strip potential markdown code blocks
        clean_text = response.text.replace('```json', '').replace('```', '').strip()
        return json.loads(clean_text)

    def translate_comparison(self, base_data, target_language):
        """
        Translates the English comparison points into the target language.
        """
        prompt = f"""
        You are Maya, a language learning content creator. 
        Take these English language comparison points and translate/localize them into {target_language}.
        Keep the "Native" column very authentic to how people actually speak in {target_language}.
        
        DATA:
        {json.dumps(base_data)}
        
        RETURN ONLY A JSON OBJECT with the same structure.
        """
        
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt
        )
        
        clean_text = response.text.replace('```json', '').replace('```', '').strip()
        return json.loads(clean_text)
