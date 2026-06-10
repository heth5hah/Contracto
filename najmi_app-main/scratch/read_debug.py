import urllib.request
import json

url = 'https://qboyfdwwrimditugblwo.supabase.co/rest/v1/rpc/get_all_credit_usage_debug'
anon_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw'

headers = {
    'apikey': anon_key,
    'Authorization': f'Bearer {anon_key}',
    'Content-Type': 'application/json'
}

req = urllib.request.Request(url, headers=headers, method='POST')
try:
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode())
        print(json.dumps(res, indent=2))
except Exception as e:
    print(f"Error: {e}")
