// VEEB API Bridge
const API_BASE = window.location.hostname === 'localhost'
  ? 'http://localhost:3003/api'
  : '/api';

export async function executeQuery(query) {
  const res = await fetch(API_BASE + '/schema/query', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query })
  });
  return res.json();
}

export async function fetchDashboard() {
  const res = await fetch(API_BASE + '/dashboard');
  return res.json();
}
