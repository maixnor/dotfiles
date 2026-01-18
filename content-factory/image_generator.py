from PIL import Image, ImageDraw, ImageFont
import os
import textwrap

def generate_comparison_card(headline, comparisons, output_path, font_path=None):
    """
    Generates a 1080x1080 comparison card.
    
    comparisons: list of dicts {"school": "...", "native": "..."}
    """
    # Create base image (Teal background as per Maya persona)
    width, height = 1080, 1080
    background_color = (0, 128, 128) # Teal
    image = Image.new('RGB', (width, height), background_color)
    draw = ImageDraw.Draw(image)
    
    # Load fonts
    font_path = font_path or os.getenv("MONTSERRAT_FONT", "/usr/share/fonts/truetype/montserrat/Montserrat-Bold.ttf")
    try:
        title_font = ImageFont.truetype(font_path, 60)
        text_font = ImageFont.truetype(font_path, 40)
        label_font = ImageFont.truetype(font_path, 30)
    except:
        # Fallback to default
        title_font = ImageFont.load_default()
        text_font = ImageFont.load_default()
        label_font = ImageFont.load_default()

    # Draw Headline
    draw.text((width/2, 100), headline, font=title_font, fill=(255, 255, 255), anchor="mm")
    
    # Draw Columns
    # Left: School (White bg, black text)
    # Right: Native (Gold bg, black text)
    
    col_width = 450
    gutter = 40
    start_y = 250
    
    # Column backgrounds
    draw.rectangle([50, 200, 500, 950], fill=(255, 255, 255)) # White
    draw.rectangle([580, 200, 1030, 950], fill=(255, 215, 0)) # Gold
    
    # Labels
    draw.text((275, 230), "SCHOOL", font=label_font, fill=(0, 0, 0), anchor="mm")
    draw.text((805, 230), "NATIVE", font=label_font, fill=(0, 0, 0), anchor="mm")
    
    curr_y = 300
    for comp in comparisons[:5]: # Max 5 items
        # Left text
        left_lines = textwrap.wrap(comp["school"], width=20)
        for line in left_lines:
            draw.text((275, curr_y), line, font=text_font, fill=(0, 0, 0), anchor="mm")
            curr_y += 50
        
        # Spacer
        curr_y += 20
        draw.line([100, curr_y, 450, curr_y], fill=(200, 200, 200), width=2)
        curr_y += 40
        
    curr_y = 300
    for comp in comparisons[:5]:
        # Right text
        right_lines = textwrap.wrap(comp["native"], width=20)
        for line in right_lines:
            draw.text((805, curr_y), line, font=text_font, fill=(0, 0, 0), anchor="mm")
            curr_y += 50
            
        curr_y += 20
        draw.line([630, curr_y, 980, curr_y], fill=(150, 150, 0), width=2)
        curr_y += 40

    image.save(output_path)
    return output_path

if __name__ == "__main__":
    # Test generation
    test_comps = [
        {"school": "How are you doing?", "native": "What's up?"},
        {"school": "I am very tired", "native": "I'm beat"},
        {"school": "That is very good", "native": "That's fire"}
    ]
    generate_comparison_card("Gen Z Slang 101", test_comps, "test_card.png")
