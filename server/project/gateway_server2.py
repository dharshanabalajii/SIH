from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import joblib

app = Flask(__name__)
CORS(app)

latest_data = {}
model = joblib.load("risk_model.pkl")

def parse_sensor_string(data_str):
    """
    Convert your raw string into a Python dictionary.
    Example input: ".Lat:11.670586,Lng:78.160726,Alt:319.3,Sat:6,Date:21/9/2025,Time:12:49:27,Touch:0,HR:49.2,SpO2:98.0,Temp:30.8"
    """
    data_str = data_str.strip(".")  # remove leading "."
    parts = data_str.split(",")
    parsed = {}
    for p in parts:
        if ":" in p:
            k, v = p.split(":", 1)
            parsed[k.strip()] = v.strip()
    return parsed

@app.route("/")
def home():
    return "palopatch gateway backend2"
@app.route("/update", methods=["POST"])
def update_location():
    global latest_data

    # The client is sending JSON with a "data" key
    payload = request.json
    raw_data = payload.get("data", "")
    print("Raw incoming data:", raw_data, type(raw_data))

    latest_data = parse_sensor_string(raw_data)
    print("Parsed data:", latest_data, type(latest_data))

    try:
        features = np.array([[
            float(latest_data.get("Temp", 0)),
            float(latest_data.get("HR", 0)),
            int(latest_data.get("Touch", 0)),   # treating Touch as sos
            float(latest_data.get("Lat", 0)),
            float(latest_data.get("Lng", 0))
        ]])
    except Exception as e:
        print("Feature extraction error:", e)
        return jsonify({"error": "Invalid sensor values", "data": latest_data}), 400

    risk_prediction = model.predict(features)[0]
    latest_data["risk"] = int(risk_prediction)
    print("Prediction:", latest_data["risk"])

    return jsonify({"status": "OK", "risk": latest_data["risk"]})



@app.route("/location", methods=["GET"])
def get_location():
    return jsonify(latest_data)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
