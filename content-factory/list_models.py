import os
from google import genai

def list_available_models():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable not set.")
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
