import os
import time
from google import genai
from google.genai import types
from PIL import Image
import io
from utils import get_secret

class MayaImageGenerator:
    def __init__(self, api_key=None):
        api_key = api_key or get_secret("GEMINI_API_KEY", "GEMINI_API_KEY_FILE")
        if not api_key:
            raise ValueError("GEMINI_API_KEY is not set!")
        self.client = genai.Client(api_key=api_key)
        # Expanded list of models based on your environment
        self.imagen_models = [
            'imagen-3.0-generate-001', 
            'imagen-3', 
            'imagen-4.0-generate-001',
            'imagen-4.0-fast-generate-001'
        ]
        self.multimodal_models = [
            'gemini-2.5-flash-image',
            'gemini-3-pro-image-preview',
            'nano-banana-pro-preview'
        ]

    def generate_maya_image(self, prompt, output_path, reference_image_path=None):
        """
        Generates an image of Maya with robust fallback and retry logic.
        """
        print(f"DEBUG: Generating image with prompt: {prompt[:100]}...")
        
        # 1. Try dedicated Imagen models first
        for model_name in self.imagen_models:
            try:
                print(f"DEBUG: Trying Imagen model {model_name}...")
                response = self.client.models.generate_images(
                    model=model_name,
                    prompt=prompt,
                    config=types.GenerateImagesConfig(
                        number_of_images=1,
                        include_rai_reason=True,
                        output_mime_type='image/png'
                    )
                )
                if response.generated_images:
                    return self._save_image(response.generated_images[0].image_bytes, output_path)
            except Exception as e:
                print(f"DEBUG: Imagen {model_name} failed: {e}")
                if "429" in str(e):
                    print("DEBUG: Rate limit hit, waiting 5s...")
                    time.sleep(5)
                continue

        # 2. Try Multimodal Content Generation (supports image context)
        print("DEBUG: Attempting Multimodal fallbacks...")
        headshot = None
        if reference_image_path and os.path.exists(reference_image_path):
            headshot = Image.open(reference_image_path)

        for model_name in self.multimodal_models:
            try:
                print(f"DEBUG: Trying Multimodal model {model_name}...")
                contents = [prompt]
                if headshot:
                    contents.append(headshot)
                
                response = self.client.models.generate_content(
                    model=model_name,
                    contents=contents
                )
                
                for part in response.candidates[0].content.parts:
                    if part.inline_data:
                        return self._save_image(part.inline_data.data, output_path)
            except Exception as e:
                print(f"DEBUG: Multimodal {model_name} failed: {e}")
                if "429" in str(e):
                    print("DEBUG: Rate limit hit, waiting 10s...")
                    time.sleep(10)
                continue

        print("ERROR: All image generation methods exhausted.")
        return None

    def _save_image(self, image_bytes, output_path):
        img = Image.open(io.BytesIO(image_bytes))
        img.save(output_path)
        print(f"DEBUG: Image successfully saved to {output_path}")
        return output_path

if __name__ == "__main__":
    pass
