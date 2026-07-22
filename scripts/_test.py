import requests
login = requests.post('http://localhost:8000/api/auth/login', json={'username': '123', 'password': '12345678'})
t = login.json()['data']['access_token']
r = requests.get('http://localhost:8000/api/wellness/daily-recommendation', headers={'Authorization': f'Bearer {t}'})
d = r.json()['data']
print('source:', d['source'])
print('tips:', d.get('wellness_tips'))
