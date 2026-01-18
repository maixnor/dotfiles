import os
import sys

# Ensure the content-factory directory is in the path
sys.path.append(os.path.dirname(__file__))

from main import run_batch_generation

def main(days: int = 7):
    """
    Triggers the batch generation of Maya's blog posts.
    
    @param days: Number of days of content to generate.
    """
    print(f"Windmill triggering batch generation for {days} days...")
    run_batch_generation(days=days)
    return {"status": "success", "message": f"Generated {days} days of content."}
