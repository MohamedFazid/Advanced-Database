# DBWT WebApp – Database, Networks & the Web (Node.js + MySQL)
**Node.js • Express • EJS • MySQL • Chart.js • dotenv**

This project is a dynamic web application built with **Node.js**, **Express**, and **EJS**, connected to a **MySQL** database using `mysql2`.  
It renders a dashboard of questions and displays query results (including multi-part results) in a clean UI. Charts are supported via **Chart.js**.

---

## 🚀 Features
- Server-side rendered pages using **EJS**
- Multiple research/questions supported via a `questions.js` configuration
- Runs SQL queries against MySQL using a connection pool (`mysql2/promise`)
- Static assets served from `/public`
- Environment-based configuration using **dotenv**
- Runs on configurable port (`PORT`, default **3000**)

---

## 🛠 Tech Stack
- **Backend:** Node.js, Express
- **Templating:** EJS
- **Database:** MySQL (`mysql2`)
- **Charts:** Chart.js
- **Config:** dotenv

---

## ✅ Prerequisites
Make sure you have:
- **Node.js** (recommended: LTS version)
- **npm**
- **MySQL server** running (local or hosted)

---

## ▶️ How to Run (IMPORTANT: Install node_modules first)

### Open the webapp folder
If you downloaded the zip, extract it and go into:

## 1) cd DBWT/webapp

## 2) npm install

## 3) Start the server
   - node app.js

## 4) Open in browser
