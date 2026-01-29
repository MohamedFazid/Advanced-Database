/* ---------------------------------
   Module Imports & Configuration
---------------------------------- */
const express = require("express");
const path = require("path");
const pool = require("./db");
require("dotenv").config();

const questions = require("./questions");

/* ---------------------------------
   App Initialization
---------------------------------- */
const app = express();

/* ---------------------------------
   View Engine & Paths
---------------------------------- */
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));

/* ---------------------------------
   Middleware
---------------------------------- */
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, "public")));

/* ---------------------------------
   Home Route
---------------------------------- */
app.get("/", (req, res) => {
  res.render("index", { questions });
});

/* ---------------------------------
   Question Results Route
---------------------------------- */
app.get("/question/:id", async (req, res) => {
  const q = questions.find(q => q.id === req.params.id);
  if (!q) return res.status(404).send("Not found");

  try {
    let results = [];

    if (q.parts && q.parts.length > 0) {
      for (let i = 0; i < q.parts.length; i++) {
        const part = q.parts[i];
        const [rows] = await pool.query(part.sql);
        results.push({
          label: part.label,
          description: part.description || "",
          rows: rows
        });
      }
    } else {
      const [rows] = await pool.query(q.sql);
      results.push({
        label: "Result",
        description: q.description || "",
        rows: rows
      });
    }

    res.render("questions", {
      question: q,
      results: results
    });

  } catch (err) {
    console.error(err);
    res.status(500).send("Database error");
  }
});

/* ---------------------------------
   Fallback 404 Handler
---------------------------------- */
app.use((req, res) => {
  res.status(404).send("Not found");
});

/* ---------------------------------
   Server Startup
---------------------------------- */
const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () => {
  console.log("Server running on port " + PORT);
});
