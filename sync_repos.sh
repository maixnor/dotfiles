#!/home/maixnor/.nix-profile/bin/bash

# Script to go through all repos under ~/repo and push changes
# Prompts user for repos with uncommitted changes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Repository Push Script ===${NC}"
echo "Checking all repositories under ~/repo..."
echo

# Find all directories containing .git folders
repos_with_uncommitted=()
repos_pushed=()
repos_failed=()
repos_no_remote=()

for repo_dir in ~/repo/*/; do
    if [ -d "$repo_dir/.git" ]; then
        repo_name=$(basename "$repo_dir")
        echo -e "${BLUE}Processing: $repo_name${NC}"
        cd "$repo_dir" || continue
        
        # Check if there are uncommitted changes
        if ! git diff-index --quiet HEAD --; then
            echo -e "${YELLOW}  ⚠️  Uncommitted changes detected${NC}"
            repos_with_uncommitted+=("$repo_dir")
            continue
        fi
        
        # Check if there are untracked files
        if [ -n "$(git ls-files --others --exclude-standard)" ]; then
            echo -e "${YELLOW}  ⚠️  Untracked files detected${NC}"
            repos_with_uncommitted+=("$repo_dir")
            continue
        fi
        
        # Check if there are staged changes
        if ! git diff-index --quiet --cached HEAD --; then
            echo -e "${YELLOW}  ⚠️  Staged changes detected${NC}"
            repos_with_uncommitted+=("$repo_dir")
            continue
        fi
        
        # Check if there's a remote configured
        if ! git remote get-url origin &>/dev/null; then
            echo -e "${YELLOW}  ⚠️  No remote 'origin' configured${NC}"
            repos_no_remote+=("$repo_dir")
            continue
        fi
        
        # Try to push
        echo "  Attempting to push..."
        if git push origin HEAD; then
            echo -e "${GREEN}  ✅ Successfully pushed${NC}"
            repos_pushed+=("$repo_dir")
        else
            echo -e "${RED}  ❌ Push failed${NC}"
            repos_failed+=("$repo_dir")
        fi
        
        echo
    fi
done

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "${GREEN}Successfully pushed (${#repos_pushed[@]}):${NC}"
for repo in "${repos_pushed[@]}"; do
    echo "  ✅ $(basename "$repo")"
done

if [ ${#repos_failed[@]} -gt 0 ]; then
    echo -e "${RED}Failed to push (${#repos_failed[@]}):${NC}"
    for repo in "${repos_failed[@]}"; do
        echo "  ❌ $(basename "$repo")"
    done
fi

if [ ${#repos_no_remote[@]} -gt 0 ]; then
    echo -e "${YELLOW}No remote configured (${#repos_no_remote[@]}):${NC}"
    for repo in "${repos_no_remote[@]}"; do
        echo "  ⚠️  $(basename "$repo")"
    done
fi

# Handle repositories with uncommitted changes
if [ ${#repos_with_uncommitted[@]} -gt 0 ]; then
    echo -e "${YELLOW}Repositories with uncommitted changes (${#repos_with_uncommitted[@]}):${NC}"
    for repo in "${repos_with_uncommitted[@]}"; do
        repo_name=$(basename "$repo")
        echo -e "${YELLOW}  ⚠️  $repo_name${NC}"
    done
    
    echo
    echo -e "${BLUE}Would you like to handle repositories with uncommitted changes?${NC}"
    
    for repo in "${repos_with_uncommitted[@]}"; do
        repo_name=$(basename "$repo")
        echo
        echo -e "${YELLOW}=== $repo_name ===${NC}"
        cd "$repo" || continue
        
        # Show status
        echo "Current status:"
        git status --short
        
        echo
        echo "What would you like to do?"
        echo "1) Commit and push all changes"
        echo "2) Show detailed status"
        echo "3) Skip this repository"
        echo "4) Exit script"
        
        read -p "Enter your choice (1-4): " choice
        
        case $choice in
            1)
                read -p "Enter commit message: " commit_msg
                if [ -n "$commit_msg" ]; then
                    git add -A
                    if git commit -m "$commit_msg"; then
                        echo "Committed successfully. Attempting to push..."
                        if git push origin HEAD; then
                            echo -e "${GREEN}✅ Successfully committed and pushed $repo_name${NC}"
                        else
                            echo -e "${RED}❌ Commit successful but push failed for $repo_name${NC}"
                        fi
                    else
                        echo -e "${RED}❌ Commit failed for $repo_name${NC}"
                    fi
                else
                    echo "Empty commit message. Skipping..."
                fi
                ;;
            2)
                echo "Detailed status for $repo_name:"
                git status
                echo
                echo "Recent commits:"
                git log --oneline -5
                read -p "Press Enter to continue..."
                ;;
            3)
                echo "Skipping $repo_name"
                ;;
            4)
                echo "Exiting script."
                exit 0
                ;;
            *)
                echo "Invalid choice. Skipping $repo_name"
                ;;
        esac
    done
fi

echo
echo -e "${BLUE}=== Script Complete ===${NC}"

