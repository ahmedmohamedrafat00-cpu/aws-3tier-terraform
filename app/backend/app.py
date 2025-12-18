from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
import os

app = Flask(__name__)
CORS(app)

db_config = {
    "host": os.environ.get("DB_HOST"),
    "user": os.environ.get("DB_USER"),
    "password": os.environ.get("DB_PASS"),
    "database": os.environ.get("DB_NAME")
}

@app.route("/health")
def health():
    return "OK", 200

@app.route("/api/add", methods=["POST"])
def add_message():
    data = request.json
    message = data.get("message")

    conn = mysql.connector.connect(**db_config)
    cursor = conn.cursor()
    cursor.execute(
        "CREATE TABLE IF NOT EXISTS messages (id INT AUTO_INCREMENT PRIMARY KEY, message TEXT)"
    )
    cursor.execute("INSERT INTO messages (message) VALUES (%s)", (message,))
    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"status": "message added"})

@app.route("/api/all", methods=["GET"])
def get_messages():
    conn = mysql.connector.connect(**db_config)
    cursor = conn.cursor()
    cursor.execute("SELECT id, message FROM messages")
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify(rows)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
