import json
import requests
import yaml
import os
import argparse
import re

# File Paths
SOURCES_FILE = "sources.json"
OUTPUT_DIR = "output"
TEMPLATES_FILE = os.path.join(OUTPUT_DIR, "templates.json")
REPORT_FILE = os.path.join(OUTPUT_DIR, "pipeline_report.json")

# GitHub configuration
GITHUB_REPO_OWNER = "himanshumishra1309"
GITHUB_REPO_NAME = "apidash-apiexplorer-poc"

# --- HELPER: AUTO-TAGGING ---
def assign_tags(title, description):
    text = f"{title} {description}".lower()
    tags = []
    if "space" in text or "astronomy" in text: tags.append("Science")
    if "finance" in text or "checkout" in text: tags.append("Finance")
    if "pet" in text or "animal" in text: tags.append("Animals")
    if not tags: tags.append("General")
    return tags

# --- HELPER: OPENAPI SCHEMA PARSING ---
def resolve_ref(ref_string, components):
    parts = ref_string.split('/')
    if parts[1] == 'components':
        return components.get(parts[2], {}).get(parts[3], {})
    return {}

def generate_sample_from_schema(schema, components):
    if "$ref" in schema:
        schema = resolve_ref(schema["$ref"], components)
    if "example" in schema:
        return schema["example"]

    schema_type = schema.get("type", "string")

    if schema_type == "object" or "properties" in schema:
        sample = {}
        for prop_name, prop_schema in schema.get("properties", {}).items():
            sample[prop_name] = generate_sample_from_schema(prop_schema, components)
        return sample
    elif schema_type == "array" and "items" in schema:
        return [generate_sample_from_schema(schema["items"], components)]
    elif schema_type == "string": return "string"
    elif schema_type == "integer": return 0
    elif schema_type == "boolean": return True
    return None

# --- HELPER: GITHUB ISSUE FETCHING ---
def fetch_community_apis_and_scores():
    """Fetches Issue URLs and their current Like/Comment scores from GitHub."""
    url = f"https://api.github.com/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/issues"
    headers = {"Accept": "application/vnd.github.squirrel-girl-preview+json"}
    params = {"labels": "community-api", "state": "all"}
    
    try:
        response = requests.get(url, headers=headers, params=params, timeout=10)
        issues = response.json() if response.status_code == 200 else []
    except:
        issues = []

    # Mock Data for testing if your repo has no issues yet
    if type(issues) is dict or len(issues) == 0:
        issues = [{
            "number": 101,
            "title": "[API]: Mock Community API",
            "body": "### API Name\nMock Community API\n\n### Raw OpenAPI URL\nhttps://raw.githubusercontent.com/OAI/OpenAPI-Specification/main/examples/v3.0/uspto.yaml\n",
            "reactions": {"+1": 45, "-1": 2, "heart": 10},
            "comments": 5,
            "html_url": "https://github.com/mock/issue"
        }]

    community_sources = []
    github_scores = {}

    for issue in issues:
        body = issue.get("body", "")
        name_match = re.search(r"### API Name\n(.*?)\n", body)
        url_match = re.search(r"### Raw OpenAPI URL\n(.*?)(?:\n|$)", body)
        
        if name_match and url_match:
            api_name = name_match.group(1).strip()
            api_url = url_match.group(1).strip()
            
            reactions = issue.get("reactions", {})
            upvotes = reactions.get("+1", 0) + reactions.get("heart", 0)
            
            score_data = {
                "upvotes": upvotes,
                "comments": issue.get("comments", 0),
                "issue_url": issue.get("html_url", "")
            }
            
            community_sources.append({"name": api_name, "url": api_url})
            github_scores[api_url] = score_data

    return community_sources, github_scores

# --- JOB 1: THE 1-HOUR FAST SYNC (ONLY UPVOTES/COMMENTS) ---
def fast_sync_scores():
    print("Running FAST SYNC (1-hour schedule): Updating likes and comments only...")
    if not os.path.exists(TEMPLATES_FILE):
        print("Templates file doesn't exist. Please run the full parse first.")
        return

    _, latest_scores = fetch_community_apis_and_scores()
    
    with open(TEMPLATES_FILE, "r") as f:
        templates = json.load(f)

    for spec in templates:
        url = spec.get("_original_url")
        if url in latest_scores:
            spec["community_score"] = latest_scores[url]

    with open(TEMPLATES_FILE, "w") as f:
        json.dump(templates, f, indent=2)
        
    print("✅ Successfully hot-swapped likes and comments without re-parsing OpenAPI files!")

# --- JOB 2: THE 6-HOUR FULL PIPELINE (HEAVY PARSING) ---
def full_pipeline_parse():
    print("Running FULL PARSE (6-hour schedule): Fetching and parsing all OpenAPI files...")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    with open(SOURCES_FILE, "r") as f:
        sources = json.load(f)

    community_sources, github_scores = fetch_community_apis_and_scores()
    
    # Combine local curated APIs with GitHub Community submitted APIs
    all_sources = sources + community_sources

    valid_templates = []
    pipeline_report = []

    for source in all_sources:
        api_name = source.get("name")
        api_url = source.get("url")
        print(f"Parsing -> {api_name}...")

        try:
            response = requests.get(api_url, timeout=10)
            response.raise_for_status() 
            
            try: spec = response.json()
            except: spec = yaml.safe_load(response.text)

            if not isinstance(spec, dict) or "paths" not in spec:
                raise ValueError("Missing 'paths' object.")

            title = spec.get("info", {}).get("title", api_name)
            description = spec.get("info", {}).get("description", "")
            servers = spec.get("servers", [{}])
            base_url = servers[0].get("url", "https://example.com")
            
            components = spec.get("components", {})
            global_auth = list(components.get("securitySchemes", {}).keys())

            endpoints = []
            for path, methods in spec["paths"].items():
                for method, details in methods.items():
                    if method.lower() not in ["get", "post", "put", "delete", "patch"]:
                        continue

                    # Parameters Extraction
                    headers, queries, path_vars = [], [], []
                    for p in details.get("parameters", []):
                        if "$ref" in p: p = resolve_ref(p["$ref"], components)
                        param_in = p.get("in", "")
                        param_info = {"name": p.get("name"), "required": p.get("required", False)}
                        if param_in == "header": headers.append(param_info)
                        elif param_in == "query": queries.append(param_info)
                        elif param_in == "path": path_vars.append(param_info)

                    # Request Body Payload Extraction
                    req_payload = None
                    req_body = details.get("requestBody", {})
                    if "$ref" in req_body: req_body = resolve_ref(req_body["$ref"], components)
                    if "application/json" in req_body.get("content", {}):
                        schema = req_body["content"]["application/json"].get("schema", {})
                        req_payload = generate_sample_from_schema(schema, components)

                    # Response Extraction
                    res_payload = None
                    responses = details.get("responses", {})
                    success_res = responses.get("200", responses.get("201", {}))
                    if "$ref" in success_res: success_res = resolve_ref(success_res["$ref"], components)
                    
                    if "application/json" in success_res.get("content", {}):
                        schema = success_res["content"]["application/json"].get("schema", {})
                        res_payload = generate_sample_from_schema(schema, components)

                    endpoints.append({
                        "method": method.upper(),
                        "path": path,
                        "summary": details.get("summary", ""),
                        "parameters": {"headers": headers, "path_variables": path_vars, "query_parameters": queries},
                        "request_body_sample": req_payload,
                        "response_body_sample": res_payload
                    })

            # Grab popularity score if this API was submitted via GitHub
            score = github_scores.get(api_url, {"upvotes": 0, "comments": 0})

            valid_templates.append({
                "name": api_name,
                "tags": assign_tags(title, description),
                "base_url": base_url,
                "_original_url": api_url, # Hidden key for fast-sync matching
                "community_score": score,
                "endpoints_count": len(endpoints),
                "endpoints": endpoints
            })
            print(f"✅ Success: Extracted {len(endpoints)} endpoints.\n")

        except Exception as e:
            print(f"❌ Failed: {str(e)}\n")
            pipeline_report.append({"name": api_name, "error": str(e)})

    # Write Outputs
    with open(TEMPLATES_FILE, "w") as f:
        json.dump(valid_templates, f, indent=2)
    with open(REPORT_FILE, "w") as f:
        json.dump(pipeline_report, f, indent=2)

    print("Full Parse Complete.")

if __name__ == "__main__":
    # Setup command line arguments so GitHub Actions can run the correct job
    parser = argparse.ArgumentParser(description="API Explorer Automation Pipeline")
    parser.add_argument("--fast-sync", action="store_true", help="Only sync GitHub likes/comments (1-Hour Job)")
    args = parser.parse_args()

    if args.fast_sync:
        fast_sync_scores()
    else:
        full_pipeline_parse()

# import json
# import requests
# import yaml
# import os

# SOURCES_FILE = "source.json"
# OUTPUT_DIR = "output"
# TEMPLATES_FILE = os.path.join(OUTPUT_DIR, "templates.json")
# REPORT_FILE = os.path.join(OUTPUT_DIR, "pipeline_report.json")

# def assign_tags(title, description):
#     text = f"{title} {description}".lower()
#     tags = []
#     if "space" in text or "astronomy" in text: tags.append("Science")
#     if "finance" in text or "checkout" in text: tags.append("Finance")
#     if "pet" in text or "animal" in text: tags.append("Animals")
#     if not tags: tags.append("General")
#     return tags

# def resolve_ref(ref_string, components):
#     """Helper to resolve OpenAPI $ref pointers"""
#     parts = ref_string.split('/')
#     if parts[1] == 'components':
#         # E.g., #/components/schemas/Pet
#         category = parts[2]
#         name = parts[3]
#         return components.get(category, {}).get(name, {})
#     return {}

# def generate_sample_from_schema(schema, components):
#     """Recursively builds realistic JSON samples based on OpenAPI Schema types"""
#     if "$ref" in schema:
#         schema = resolve_ref(schema["$ref"], components)

#     # If there's an explicit example, prioritize it
#     if "example" in schema:
#         return schema["example"]

#     schema_type = schema.get("type", "string")

#     if schema_type == "object" or "properties" in schema:
#         sample = {}
#         for prop_name, prop_schema in schema.get("properties", {}).items():
#             sample[prop_name] = generate_sample_from_schema(prop_schema, components)
#         return sample
        
#     elif schema_type == "array" and "items" in schema:
#         return [generate_sample_from_schema(schema["items"], components)]
        
#     elif schema_type == "string":
#         # Handle string formats (date-time, email, etc.)
#         fmt = schema.get("format", "")
#         if fmt == "date-time": return "2024-03-26T12:00:00Z"
#         if fmt == "email": return "user@example.com"
#         return "string"
#     elif schema_type == "integer":
#         return 0
#     elif schema_type == "number":
#         return 0.0
#     elif schema_type == "boolean":
#         return True
        
#     return None

# def process_apis():
#     os.makedirs(OUTPUT_DIR, exist_ok=True)
#     with open(SOURCES_FILE, "r") as f:
#         sources = json.load(f)

#     valid_templates = []
#     pipeline_report = []

#     for source in sources:
#         api_name = source.get("name")
#         api_url = source.get("url")
#         print(f"Parsing -> {api_name}...")

#         try:
#             response = requests.get(api_url, timeout=10)
#             response.raise_for_status() 
            
#             try: spec = response.json()
#             except: spec = yaml.safe_load(response.text)

#             if not isinstance(spec, dict) or "paths" not in spec:
#                 raise ValueError("Missing 'paths' object.")

#             title = spec.get("info", {}).get("title", api_name)
#             description = spec.get("info", {}).get("description", "")
#             servers = spec.get("servers", [])
#             base_url = servers[0].get("url") if servers else "https://example.com"
#             components = spec.get("components", {})
            
#             # Global auth definitions
#             security_schemes = components.get("securitySchemes", {})
#             global_auth = list(security_schemes.keys())

#             endpoints = []
#             for path, methods in spec["paths"].items():
#                 for method, details in methods.items():
#                     if method.lower() not in ["get", "post", "put", "delete", "patch"]:
#                         continue

#                     # 1. Parameter Extraction (Headers, Query, Path)
#                     headers, queries, path_vars = [], [], []
#                     params = details.get("parameters", [])
                    
#                     for p in params:
#                         if "$ref" in p:
#                             p = resolve_ref(p["$ref"], components)
                            
#                         param_in = p.get("in", "")
#                         param_info = {
#                             "name": p.get("name"),
#                             "required": p.get("required", False),
#                             "type": p.get("schema", {}).get("type", "string")
#                         }
                        
#                         if param_in == "header": headers.append(param_info)
#                         elif param_in == "query": queries.append(param_info)
#                         elif param_in == "path": path_vars.append(param_info)

#                     # 2. Extract Security/Auth Requirements for this specific endpoint
#                     endpoint_auth = []
#                     for security_req in details.get("security", []):
#                         # Extracts the names of required auth schemes (e.g. ['api_key', 'oauth2'])
#                         endpoint_auth.extend(list(security_req.keys()))

#                     # 3. Request Payload (Body)
#                     request_payload = None
#                     request_body = details.get("requestBody", {})
#                     if "$ref" in request_body:
#                         request_body = resolve_ref(request_body["$ref"], components)
                        
#                     content = request_body.get("content", {})
#                     if "application/json" in content:
#                         schema = content["application/json"].get("schema", {})
#                         request_payload = generate_sample_from_schema(schema, components)

#                     # 4. Response Payload
#                     response_payload = None
#                     responses = details.get("responses", {})
#                     success_res = responses.get("200", responses.get("201", responses.get("default", {})))
                    
#                     if "$ref" in success_res:
#                         success_res = resolve_ref(success_res["$ref"], components)

#                     res_content = success_res.get("content", {})
#                     if "application/json" in res_content:
#                         res_schema = res_content["application/json"].get("schema", {})
#                         response_payload = generate_sample_from_schema(res_schema, components)

#                     endpoints.append({
#                         "method": method.upper(),
#                         "path": path,
#                         "summary": details.get("summary", "No summary provided"),
#                         "auth_required": endpoint_auth if endpoint_auth else global_auth,
#                         "parameters": {
#                             "headers": headers,
#                             "path_variables": path_vars,
#                             "query_parameters": queries
#                         },
#                         "request_body_sample": request_payload,
#                         "response_body_sample": response_payload
#                     })

#             valid_templates.append({
#                 "name": api_name,
#                 "tags": assign_tags(title, description),
#                 "base_url": base_url,
#                 "global_auth_methods": security_schemes,
#                 "endpoints_count": len(endpoints),
#                 "endpoints": endpoints
#             })
#             print(f"✅ Success: Parsed {len(endpoints)} endpoints.\n")

#         except Exception as e:
#             print(f"❌ Failed: {str(e)}\n")
#             pipeline_report.append({"name": api_name, "error": str(e)})

#     with open(TEMPLATES_FILE, "w") as f:
#         json.dump(valid_templates, f, indent=2)
#     with open(REPORT_FILE, "w") as f:
#         json.dump(pipeline_report, f, indent=2)

# if __name__ == "__main__":
#     process_apis()