const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');

const app = express();
app.use(cors());
app.use(express.json());

// Serve frontend files
app.use(express.static(path.join(__dirname, '..', 'frontend')));

// MySQL connection pool
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'VEEB',
  waitForConnections: true,
  connectionLimit: 10,
  charset: 'utf8mb4'
});

// Test DB connection on startup
(async () => {
  try {
    const conn = await pool.getConnection();
    console.log('✅ Connected to VEEB database');
    conn.release();
  } catch (err) {
    console.error('❌ Database connection failed:', err.message);
  }
})();

// ── SQL Query Endpoint (same pattern as other projects) ──
app.post('/api/schema/query', async (req, res) => {
  const { query } = req.body;
  if (!query) return res.status(400).json({ error: 'No query provided' });

  try {
    const [rows, fields] = await pool.query(query);

    // SELECT queries return arrays
    if (Array.isArray(rows)) {
      const fieldNames = fields ? fields.map(f => f.name) : [];
      return res.json({ rows, fields: fieldNames });
    }

    // INSERT/UPDATE/DELETE return result objects
    return res.json({ rows, fields: [] });
  } catch (err) {
    console.error('SQL Error:', err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ── Dashboard Stats Endpoint ──
app.get('/api/dashboard', async (req, res) => {
  try {
    const [vehicles] = await pool.query('SELECT COUNT(*) as count FROM Vehicle');
    const [parked] = await pool.query("SELECT COUNT(*) as count FROM Entry_Exit_Log WHERE status = 'Parked'");
    const [slots] = await pool.query('SELECT COUNT(*) as total, SUM(is_occupied) as occupied FROM Parking_Slot');
    const [todayRev] = await pool.query('SELECT COALESCE(SUM(amount),0) as revenue FROM Billing WHERE DATE(billed_at) = CURDATE()');
    const [totalRev] = await pool.query('SELECT COALESCE(SUM(amount),0) as revenue FROM Billing');

    res.json({
      totalVehicles: vehicles[0].count,
      currentlyParked: parked[0].count,
      totalSlots: slots[0].total,
      occupiedSlots: slots[0].occupied || 0,
      todayRevenue: todayRev[0].revenue,
      totalRevenue: totalRev[0].revenue
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3003;
app.listen(PORT, () => {
  console.log(`🚗 VEEB Server running on http://localhost:${PORT}`);
});
