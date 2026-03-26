import json
import requests
import yaml
import os

SOURCES_FILE = "source.json"
OUTPUT_DIR = "output"
TEMPLATES_FILE = os.path.join(OUTPUT_DIR, "templates.json")
REPORT_FILE = os.path.join(OUTPUT_DIR, "pipeline_report.json")

def assign_tags(title, description):
    text = f"{title} {description}".lower()
    tags = []
    if "space" in text or "astronomy" in text: tags.append("Science")
    if "finance" in text or "checkout" in text: tags.append("Finance")
    if "pet" in text or "animal" in text: tags.append("Animals")
    if not tags: tags.append("General")
    return tags

def resolve_ref(ref_string, components):
    """Helper to resolve OpenAPI $ref pointers"""
    parts = ref_string.split('/')
    if parts[1] == 'components':
        # E.g., #/components/schemas/Pet
        category = parts[2]
        name = parts[3]
        return components.get(category, {}).get(name, {})
    return {}

def generate_sample_from_schema(schema, components):
    """Recursively builds realistic JSON samples based on OpenAPI Schema types"""
    if "$ref" in schema:
        schema = resolve_ref(schema["$ref"], components)

    # If there's an explicit example, prioritize it
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
        
    elif schema_type == "string":
        # Handle string formats (date-time, email, etc.)
        fmt = schema.get("format", "")
        if fmt == "date-time": return "2024-03-26T12:00:00Z"
        if fmt == "email": return "user@example.com"
        return "string"
    elif schema_type == "integer":
        return 0
    elif schema_type == "number":
        return 0.0
    elif schema_type == "boolean":
        return True
        
    return None

def process_apis():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(SOURCES_FILE, "r") as f:
        sources = json.load(f)

    valid_templates = []
    pipeline_report = []

    for source in sources:
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
            servers = spec.get("servers", [])
            base_url = servers[0].get("url") if servers else "https://example.com"
            components = spec.get("components", {})
            
            # Global auth definitions
            security_schemes = components.get("securitySchemes", {})
            global_auth = list(security_schemes.keys())

            endpoints = []
            for path, methods in spec["paths"].items():
                for method, details in methods.items():
                    if method.lower() not in ["get", "post", "put", "delete", "patch"]:
                        continue

                    # 1. Parameter Extraction (Headers, Query, Path)
                    headers, queries, path_vars = [], [], []
                    params = details.get("parameters", [])
                    
                    for p in params:
                        if "$ref" in p:
                            p = resolve_ref(p["$ref"], components)
                            
                        param_in = p.get("in", "")
                        param_info = {
                            "name": p.get("name"),
                            "required": p.get("required", False),
                            "type": p.get("schema", {}).get("type", "string")
                        }
                        
                        if param_in == "header": headers.append(param_info)
                        elif param_in == "query": queries.append(param_info)
                        elif param_in == "path": path_vars.append(param_info)

                    # 2. Extract Security/Auth Requirements for this specific endpoint
                    endpoint_auth = []
                    for security_req in details.get("security", []):
                        # Extracts the names of required auth schemes (e.g. ['api_key', 'oauth2'])
                        endpoint_auth.extend(list(security_req.keys()))

                    # 3. Request Payload (Body)
                    request_payload = None
                    request_body = details.get("requestBody", {})
                    if "$ref" in request_body:
                        request_body = resolve_ref(request_body["$ref"], components)
                        
                    content = request_body.get("content", {})
                    if "application/json" in content:
                        schema = content["application/json"].get("schema", {})
                        request_payload = generate_sample_from_schema(schema, components)

                    # 4. Response Payload
                    response_payload = None
                    responses = details.get("responses", {})
                    success_res = responses.get("200", responses.get("201", responses.get("default", {})))
                    
                    if "$ref" in success_res:
                        success_res = resolve_ref(success_res["$ref"], components)

                    res_content = success_res.get("content", {})
                    if "application/json" in res_content:
                        res_schema = res_content["application/json"].get("schema", {})
                        response_payload = generate_sample_from_schema(res_schema, components)

                    endpoints.append({
                        "method": method.upper(),
                        "path": path,
                        "summary": details.get("summary", "No summary provided"),
                        "auth_required": endpoint_auth if endpoint_auth else global_auth,
                        "parameters": {
                            "headers": headers,
                            "path_variables": path_vars,
                            "query_parameters": queries
                        },
                        "request_body_sample": request_payload,
                        "response_body_sample": response_payload
                    })

            valid_templates.append({
                "name": api_name,
                "tags": assign_tags(title, description),
                "base_url": base_url,
                "global_auth_methods": security_schemes,
                "endpoints_count": len(endpoints),
                "endpoints": endpoints
            })
            print(f"✅ Success: Parsed {len(endpoints)} endpoints.\n")

        except Exception as e:
            print(f"❌ Failed: {str(e)}\n")
            pipeline_report.append({"name": api_name, "error": str(e)})

    with open(TEMPLATES_FILE, "w") as f:
        json.dump(valid_templates, f, indent=2)
    with open(REPORT_FILE, "w") as f:
        json.dump(pipeline_report, f, indent=2)

if __name__ == "__main__":
    process_apis()