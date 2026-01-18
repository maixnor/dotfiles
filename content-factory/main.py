import sys
import argparse
from orchestrator import MayaOrchestrator
from publisher import publish_due_items

def main():
    parser = argparse.ArgumentParser(description="LanguageBuddy Content Factory CLI")
    parser.add_argument("command", choices=["brainstorm", "draft", "approve", "publish", "list-ideas"], help="Command to run")
    parser.add_argument("--count", type=int, default=10, help="Number of topics to brainstorm")
    parser.add_argument("--ids", nargs="+", type=int, help="Idea IDs to draft")
    parser.add_argument("--group", type=str, help="Topic Group ID to approve/translate")
    
    args = parser.parse_args()
    orc = MayaOrchestrator()

    if args.command == "brainstorm":
        orc.step1_morning_brainstorm(count=args.count)
        print("Brainstorming complete.")

    elif args.command == "list-ideas":
        from models import TopicIdea
        ideas = orc.session.query(TopicIdea).filter(TopicIdea.status == 'suggested').all()
        print("\n--- Suggested Topics ---")
        for i in ideas:
            print(f"[{i.id}] {i.topic}")
        
    elif args.command == "draft":
        if not args.ids:
            print("Error: --ids required for draft command")
            return
        orc.step2_draft_selected_en(args.ids)
        print(f"Drafting for IDs {args.ids} complete.")
        
    elif args.command == "approve":
        if not args.group:
            print("Error: --group (UUID) required for approve command")
            return
        orc.step3_expand_approved_translations(args.group)
        orc.step4_schedule_queue()
        print(f"Topic group {args.group} approved and scheduled.")
        
    elif args.command == "publish":
        publish_due_items()
        print("Publishing check complete.")

if __name__ == "__main__":
    main()
