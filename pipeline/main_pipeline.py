import json
import os
from fetch_local_sources import process_local_sources
from fetch_github_issues import process_github_issues

def main():
    os.makedirs("output", exist_ok=True)
    print("--- Starting 6-Hour Heavy Parse Pipeline (Sequential) ---")
    
    # 1. Process Local Sources First
    local_templates, local_reports = process_local_sources()

    # 2. Process GitHub Issues Second
    github_templates, github_reports = process_github_issues()

    all_templates = local_templates + github_templates
    all_reports = local_reports + github_reports

    with open("output/templates.json", "w") as f:
        json.dump(all_templates, f, indent=2)
        
    with open("output/pipeline_report.json", "w") as f:
        json.dump(all_reports, f, indent=2)

    print(f"\n✅ Heavy Pipeline Complete! Saved {len(all_templates)} templates.")

if __name__ == "__main__":
    main()