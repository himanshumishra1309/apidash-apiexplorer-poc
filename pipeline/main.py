import json
import requests
import yaml
import os

# Paths
SOURCES_FILE = "source.json"
OUTPUT_DIR = "output"
TEMPLATES_FILE = os.path.join(OUTPUT_DIR, "templates.json")
REPORT_FILE = os.path.join(OUTPUT_DIR, "pipeline_report.json")

# Step 4: Rule-based Tagging System
def assign_tags(title, description):
    text = f"{title} {description}".lower()
    tags = []
    
    if "weather" in text or "meteo" in text or "forecast" in text:
        tags.append("Weather")
    if "coin" in text or "finance" in text or "currency" in text or "exchange" in text:
        tags.append("Finance")
    if "nasa" in text or "space" in text or "astronomy" in text:
        tags.append("Science")
        
    # Fallback tag
    if not tags:
        tags.append("General")
        
    return tags

def process_apis():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(SOURCES_FILE, "r") as f:
        sources = json.load(f)

    valid_templates = []
    pipeline_report = []

    print(f"Starting pipeline run for {len(sources)} APIs...\n")

    for source in sources:
        api_name = source.get("name")
        api_url = source.get("url")
        print(f"Fetch target -> {api_name}")

        try:
            response = requests.get(api_url, timeout=10)
            response.raise_for_status() 
            
            content_type = response.headers.get("Content-Type", "")
            if "yaml" in api_url or "yaml" in content_type:
                spec = yaml.safe_load(response.text)
            else:
                spec = response.json()

            if "paths" not in spec:
                raise ValueError("Validation Failed: Missing 'paths' object.")

            info = spec.get("info", {})
            title = info.get("title", api_name)
            description = info.get("description", "")
            servers = spec.get("servers", [])
            base_url = servers[0].get("url") if servers else "https://unknown-server.com"

            # Run our Auto-Tagger
            tags = assign_tags(title, description)

            endpoints = []
            for path, methods in spec["paths"].items():
                for method, details in methods.items():
                    if method.lower() in ["get", "post", "put", "delete", "patch"]:
                        endpoints.append({
                            "method": method.upper(),
                            "path": path,
                            "summary": details.get("summary", "No summary provided")
                        })

            cleaned_template = {
                "name": api_name,
                "title": title,
                "tags": tags,  # SEGREGATION ADDED HERE
                "base_url": base_url,
                "endpoints_count": len(endpoints),
                "endpoints": endpoints
            }

            valid_templates.append(cleaned_template)
            print(f"✅ Success: Categorized as {tags}\n")

        except requests.exceptions.RequestException as e:
            print(f"❌ Failed (Network): {e}\n")
            pipeline_report.append({"name": api_name, "error": "Network Error or 404"})
        except Exception as e:
            print(f"❌ Failed (Parsing): {e}\n")
            pipeline_report.append({"name": api_name, "error": str(e)})

    with open(TEMPLATES_FILE, "w") as f:
        json.dump(valid_templates, f, indent=2)

    with open(REPORT_FILE, "w") as f:
        json.dump(pipeline_report, f, indent=2)

    print(f"Pipeline Complete! Check output/templates.json for the formatted data.")

if __name__ == "__main__":
    process_apis()