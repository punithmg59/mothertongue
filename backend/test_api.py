import requests

# Test the translation API with language names
url = "http://localhost:8000/translate"
payload = {
    "text_blocks": [
        {
            "text": "नमस्ते",
            "x": 0,
            "y": 0,
            "width": 100,
            "height": 30
        }
    ],
    "source_language": "hindi",
    "target_language": "english"
}

print("Testing translation API with language names...")
print(f"Request: {payload}")
print()

response = requests.post(url, json=payload)

print(f"Status Code: {response.status_code}")
print(f"Response: {response.json()}")
