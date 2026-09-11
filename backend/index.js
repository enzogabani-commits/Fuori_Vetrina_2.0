require("dotenv").config();

const express = require("express");
const path = require("path");
const { Pool } = require("pg");

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT
});
pool.query("SELECT 1")
  .then(() => console.log("PostgreSQL collegato correttamente"))
  .catch(err => console.error("Errore PostgreSQL:", err.message));

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, "..")));
  app.get("/api/stories", async (req, res) => {
  try {
    const result = await pool.query(
  `SELECT s.*, c.name AS category, s.author_name AS name
   FROM stories s
   JOIN categories c ON c.id = s.category_id
   ORDER BY s.created_at DESC`
);
    res.json(result.rows);
  } catch (err) {
    console.error("Errore lettura storie:", err.message);
res.status(500).json({ error: "Errore lettura storie" });
}});

app.post("/api/stories", async (req, res) => {
  try {
    const {
      user_id,
      author_name,
      title,
      body,
      category_id,
      consent_confirmed
    } = req.body;

    if (!title || !body || !category_id) {
      return res.status(400).json({
        error: "Titolo, testo e categoria sono obbligatori"
      });
    }

    const result = await pool.query(
      `INSERT INTO stories
       (user_id, author_name, title, body, category_id, consent_confirmed)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        user_id || null,
        author_name || null,
        title,
        body,
        category_id,
        consent_confirmed === true
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error("Errore inserimento storia:", err.message);
    res.status(500).json({ error: "Errore inserimento storia" });
  }
});
app.get("/", (req, res) => {
  res.json({
    message: "Backend Fuori Vetrina 2.0 attivo"
  });
});

app.listen(PORT, () => {
  console.log(`Server avviato su http://localhost:${PORT}`);
});
