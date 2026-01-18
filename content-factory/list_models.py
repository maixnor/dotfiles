import os
from google import genai
from utils import get_secret

def list_available_models():
    api_key = get_secret("GEMINI_API_KEY")
    if not api_key:
        print("Error: Gemini API key not found.")
        return

    client = genai.Client(api_key=api_key)
    print("--- Available Models ---")
    try:
        for model in client.models.list():
            # Print the whole object to see structure
            print(model)
    except Exception as e:
        print(f"Error listing models: {e}")

if __name__ == "__main__":
    list_available_models()
