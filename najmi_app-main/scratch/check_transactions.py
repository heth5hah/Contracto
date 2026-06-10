import urllib.request
import json

url = 'https://qboyfdwwrimditugblwo.supabase.co/rest/v1/'
anon_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFib3lmZHd3cmltZGl0dWdibHdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAwNDYwNDcsImV4cCI6MjA2NTYyMjA0N30.1k-tFyCkGWpTWtpTn7q2-vKiIsdXpslWPgnhqCGn8Kw'

headers = {
    'apikey': anon_key,
    'Authorization': f'Bearer {anon_key}',
    'Content-Type': 'application/json'
}

def query_table(table):
    req = urllib.request.Request(f"{url}{table}?select=*", headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        print(f"Error querying {table}: {e}")
        return []

print("=== credit_usage ===")
usage = query_table('credit_usage')
for u in usage:
    print(f"Id: {u.get('id')}, AccountId: {u.get('credit_account_id')}, Type: {u.get('transaction_type')}, Amount: {u.get('amount')}, Desc: {u.get('description')}, Balance After: {u.get('balance_after')}")

print("\n=== business_credit_accounts ===")
accounts = query_table('business_credit_accounts')
for a in accounts:
    print(f"Id: {a.get('id')}, UserId: {a.get('user_id')}, Limit: {a.get('credit_limit')}, Available: {a.get('available_credit')}, Used: {a.get('used_credit')}, Status: {a.get('status')}")
