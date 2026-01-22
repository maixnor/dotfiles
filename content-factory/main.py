import sys
import argparse
import json
from orchestrator import MayaOrchestrator
from publisher import publish_due_items

def main():
    parser = argparse.ArgumentParser(description="LanguageBuddy Content Factory CLI")
    parser.add_argument("command", choices=["brainstorm", "discovery", "draft", "approve", "disapprove", "publish", "list-ideas", "list-content", "list-queue", "get-preview", "scrape", "cleanup"], help="Command to run")
    parser.add_argument("--count", type=int, default=10, help="Number of topics to brainstorm")
    parser.add_argument("--status", type=str, default="draft_en", help="Status to filter content items")
    parser.add_argument("--subreddits", nargs="+", default=["languagelearning", "EnglishLearning", "learnenglish", "grammar", "Spanish", "French", "German"], help="Subreddits to scour")
    parser.add_argument("--ids", nargs="+", type=int, help="Idea IDs to draft")
    parser.add_argument("--group", type=str, help="Topic Group ID to approve/translate/disapprove")
    parser.add_argument("--url", type=str, help="URL to scrape")
    parser.add_argument("--json", action="store_true", help="Output results in JSON format")
    
    args = parser.parse_args()
    orc = MayaOrchestrator()

    if args.command == "scrape":
        if not args.url:
            print("Error: --url required for scrape command")
            return
        from scraper import process_url
        process_url(args.url)

    elif args.command == "brainstorm":
        topics = orc.step1_morning_brainstorm(count=args.count)
        if args.json:
            print(json.dumps({"status": "success", "topics": topics}))
        else:
            print("Brainstorming complete.")

    elif args.command == "discovery":
        topics = orc.discovery_phase(subreddits=args.subreddits)
        if args.json:
            print(json.dumps({"status": "success", "topics": topics}))
        else:
            print("Community discovery complete. Check 'list-ideas' for new lead-gen topics.")

    elif args.command == "list-ideas":
        from models import TopicIdea
        ideas = orc.session.query(TopicIdea).filter(TopicIdea.status == 'suggested').all()
        
        if args.json:
            data = [
                {
                    "id": i.id,
                    "topic": i.topic,
                    "source": i.source or "brainstorm",
                    "created_at": i.created_at.isoformat() if i.created_at else None
                } for i in ideas
            ]
            print(json.dumps(data))
        else:
            print("\n--- Suggested Topics ---")
            for i in ideas:
                print(f"[{i.id}] {i.topic} ({i.source or 'brainstorm'})")

    elif args.command == "list-content":
        from windmill_scripts import get_content_items
        data = get_content_items(status=args.status)
        if args.json:
            print(json.dumps(data))
        else:
            print(f"\n--- Content Items ({args.status}) ---")
            for i in data:
                print(f"[{i['id']}] {i['headline']} (Group: {i['topic_group_id']})")

    elif args.command == "list-queue":
        from windmill_scripts import get_scheduled_queue
        data = get_scheduled_queue()
        if args.json:
            print(json.dumps(data))
        else:
            print("\n--- Scheduled Queue (Upcoming First) ---")
            for i in data:
                print(f"[{i['scheduled_at']}] {i['target_language']}: {i['headline']} (ID: {i['id']})")

    elif args.command == "get-preview":
        if not args.group:
            if args.json:
                print(json.dumps({"status": "error", "message": "--group required"}))
            else:
                print("Error: --group required")
            return
        from windmill_scripts import get_preview
        data = get_preview(args.group)
        if args.json:
            print(json.dumps(data))
        else:
            print(f"\n--- Preview for {args.group} ---")
            print(f"Headline: {data.get('headline')}")
            print(f"Image: {data.get('image_url')}")
            print("-" * 20)
            print(data.get('content'))
        
    elif args.command == "draft":
        if not args.ids:
            if args.json:
                print(json.dumps({"status": "error", "message": "--ids required"}))
            else:
                print("Error: --ids required for draft command")
            return
        groups = orc.step2_draft_selected_en(args.ids)
        if args.json:
            print(json.dumps({"status": "success", "ids": args.ids, "topic_group_ids": groups}))
        else:
            print(f"Drafting for IDs {args.ids} complete.")
        
    elif args.command == "approve":
        if not args.group:
            if args.json:
                print(json.dumps({"status": "error", "message": "--group required"}))
            else:
                print("Error: --group (UUID) required for approve command")
            return
        orc.step3_expand_approved_translations(args.group)
        orc.step4_schedule_queue()
        if args.json:
            print(json.dumps({"status": "success", "group": args.group}))
        else:
            print(f"Topic group {args.group} approved and scheduled.")

    elif args.command == "disapprove":
        if not args.group:
            if args.json:
                print(json.dumps({"status": "error", "message": "--group required"}))
            else:
                print("Error: --group (UUID) required for disapprove command")
            return
        orc.disapprove_group(args.group)
        if args.json:
            print(json.dumps({"status": "success", "group": args.group}))
        else:
            print(f"Topic group {args.group} disapproved. Idea reset to suggested.")
        
    elif args.command == "publish":
        count = publish_due_items()
        if args.json:
            print(json.dumps({"status": "success", "published_count": count}))
        else:
            print(f"Publishing check complete. {count} items published.")

    elif args.command == "cleanup":
        from models import TopicIdea
        # Find topics that look like conversational noise
        noise = orc.session.query(TopicIdea).filter(
            TopicIdea.status == 'suggested'
        ).all()
        
        count = 0
        for i in noise:
            text = i.topic.lower()
            if text.startswith(('hey', 'here are', 'i am', 'maya here', 'honestly', 'hi')):
                orc.session.delete(i)
                count += 1
        
        orc.session.commit()
        if args.json:
            print(json.dumps({"status": "success", "deleted_count": count}))
        else:
            print(f"Cleanup complete. Deleted {count} junk topics.")

if __name__ == "__main__":
    main()
