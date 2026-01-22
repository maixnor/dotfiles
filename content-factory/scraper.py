import httpx
from bs4 import BeautifulSoup
from models import TopicIdea, Session
import xml.etree.ElementTree as ET

def scrape_reddit_hot(subreddit="languagelearning"):
    """
    Fetches hot topics from a subreddit to find real user pain points.
    """
    url = f"https://www.reddit.com/r/{subreddit}/hot.json?limit=15"
    headers = {"User-Agent": "MayaContentFactory/0.1 (LeadGen Engine)"}
    
    with httpx.Client(follow_redirects=True) as client:
        try:
            resp = client.get(url, headers=headers)
            if resp.status_code != 200:
                return []
            
            data = resp.json()
            posts = []
            for post in data['data']['children']:
                p = post['data']
                if p['is_self']: # Text posts are best for finding problems
                    posts.append({
                        "title": p['title'],
                        "content": p['selftext'][:1000],
                        "source": f"reddit:r/{subreddit}"
                    })
            return posts
        except Exception as e:
            print(f"Reddit scrape failed: {e}")
            return []

def scrape_news_rss(url):
    """
    Fetches news from RSS feeds (BBC Languages, etc.)
    """
    with httpx.Client() as client:
        try:
            resp = client.get(url)
            root = ET.fromstring(resp.content)
            news = []
            for item in root.findall('.//item'):
                news.append({
                    "title": item.find('title').text,
                    "content": item.find('description').text if item.find('description') is not None else "",
                    "source": f"rss:{url}"
                })
            return news
        except Exception as e:
            print(f"RSS scrape failed: {e}")
            return []