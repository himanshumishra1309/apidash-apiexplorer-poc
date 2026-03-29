import json
import os
import requests
import re

GITHUB_REPO_OWNER = "himanshumishra1309"
GITHUB_REPO_NAME = "apidash"
TEMPLATES_FILE = "output/templates.json"

def main():
    print("\n--- Running 1-Hour Fast Sync (Scores/Comments Only) ---")
    if not os.path.exists(TEMPLATES_FILE):
        print("❌ templates.json missing. Run main_pipeline.py first.")
        return

    url = f"https://api.github.com/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/issues"
    headers = {"Accept": "application/vnd.github.squirrel-girl-preview+json"}
    params = {"labels": "community-api", "state": "all"}
    
    print(f"[*] Fetching latest engagement from GitHub...")
    try:
        response = requests.get(url, headers=headers, params=params, timeout=10)
        issues = response.json() if response.status_code == 200 else []
    except Exception as e:
        print(f"❌ Failed to reach GitHub: {e}")
        return

    if isinstance(issues, dict):
        print(f"❌ API Error / Rate Limit: {issues}")
        return

    # Extract just the URLs and their current scores
    latest_scores = {}
    for issue in issues:
        body = issue.get("body", "")
        if not body: continue
        
        url_match = re.search(r"### Raw OpenAPI URL[\r\n]+([^\r\n]+)", body)
        if url_match:
            api_url = url_match.group(1).strip()
            reactions = issue.get("reactions", {})
            latest_scores[api_url] = {
                "upvotes": reactions.get("+1", 0) + reactions.get("heart", 0),
                "comments": issue.get("comments", 0)
            }

    # Load existing heavy-parsed data
    with open(TEMPLATES_FILE, "r") as f:
        templates = json.load(f)

    # Quickly update just the scores
    updated_count = 0
    for spec in templates:
        url = spec.get("_original_url")
        if url in latest_scores:
            spec["community_score"] = latest_scores[url]
            updated_count += 1

    # Save it back
    with open(TEMPLATES_FILE, "w") as f:
        json.dump(templates, f, indent=2)
        
    print(f"✅ Fast Sync Complete: Updated likes & comments for {updated_count} APIs!")

if __name__ == "__main__":
    main()