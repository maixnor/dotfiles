import httpx
from bs4 import BeautifulSoup
import os
import sys
from models import ContentItem, TopicIdea, Session
from utils import get_secret

def scrape_article(url):
    """
    Generic scraper that attempts to extract title and body from a language blog.
    """
    print(f"Scraping {url}...")
    
    try:
        response = httpx.get(url, follow_redirects=True, timeout=10.0)
        response.raise_for_status()
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return None

    soup = BeautifulSoup(response.text, 'html.parser')
    
    # Attempt to find title
    title = soup.find('h1').text.strip() if soup.find('h1') else "No Title Found"
    
    # Attempt to find main content (heuristics for common blogs)
    # We look for <article>, <main>, or large <div> blocks
    content_area = soup.find('article') or soup.find('main') or soup.find('div', class_='entry-content')
    
    if not content_area:
        # Fallback to body
        content_area = soup.find('body')

    # Strip scripts and styles
    for script in content_area(["script", "style"]):
        script.extract()

    body_text = content_area.get_text(separator='\n').strip()
    
    return {
        "title": title,
        "body": body_text,
        "source_url": url
    }

def process_url(url):
    """
    Checks for duplicates and saves to topic_ideas.
    """
    session = Session()
    
    # Check for duplicates
    existing = session.query(TopicIdea).filter(TopicIdea.source == url).first()
    if existing:
        print(f"URL already processed: {url}")
        return
    
    result = scrape_article(url)
    if result:
        new_idea = TopicIdea(
            topic=result["title"],
            source=url,
            status='suggested'
        )
        session.add(new_idea)
        session.commit()
        print(f"Successfully added idea: {result['title']}")
    
    session.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: maya-cli scrape <url>")
    else:
        process_url(sys.argv[1])
