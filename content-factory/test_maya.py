import os
import shutil
from blog_engine import MayaBlogEngine
from image_gen import MayaImageGenerator
from persona import TARGET_LANGUAGES
from utils import get_secret

def generate_preview_pack(topic="The secret etiquette of ordering tapas in Seville"):
    """
    Generates a full 4-language preview pack in content-factory/preview/
    """
    api_key = get_secret("GEMINI_API_KEY")
    if not api_key:
        print("CRITICAL ERROR: Gemini API key not found.")
        return

    preview_dir = "preview"
    if os.path.exists(preview_dir):
        shutil.rmtree(preview_dir)
    os.makedirs(preview_dir)

    engine = MayaBlogEngine(api_key=api_key)
    image_gen = MayaImageGenerator(api_key=api_key)
    
    # Path to Maya's headshot for visual consistency
    headshot_path = os.path.join(os.path.dirname(__file__), "../persona/maya.png")

    print(f"--- GENERATING PREVIEW PACK FOR: {topic} ---")

    # 1. Generate English first to get the image prompt
    print("STEP 1: Generating text content and image prompt...")
    try:
        base_result = engine.generate_blog(topic, "English")
    except Exception as e:
        print(f"CRITICAL ERROR during text generation: {e}")
        return
    
    # 2. Generate the single image for the topic
    print("STEP 2: Generating the thumbnail image with headshot reference...")
    image_path = os.path.join(preview_dir, "maya_thumbnail.png")
    
    # Passing the headshot path as the reference image
    success_path = image_gen.generate_maya_image(
        base_result["image_prompt"], 
        image_path, 
        reference_image_path=headshot_path
    )
    
    if not success_path:
        print("CRITICAL ERROR: Image generation failed. No PNG was created.")
    else:
        print(f"SUCCESS: Image created at {success_path}")

    # 3. Generate the other languages
    print("STEP 3: Generating other language versions...")
    for lang in TARGET_LANGUAGES:
        print(f"  > Processing {lang}...")
        if lang == "English":
            res = base_result
        else:
            res = engine.generate_blog(topic, lang)
            
        md_path = os.path.join(preview_dir, f"blog_{lang.lower()}.md")
        with open(md_path, "w") as f:
            f.write(f"# {topic}\n\n")
            f.write("![Maya Thumbnail](maya_thumbnail.png)\n\n")
            f.write(res["markdown"])
            
    print(f"\nCOMPLETED! Check the '{preview_dir}' folder.")

if __name__ == "__main__":
    generate_preview_pack()