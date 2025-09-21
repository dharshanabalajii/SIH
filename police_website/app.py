import eventlet
eventlet.monkey_patch()

from flask import Flask, render_template, jsonify
from flask_socketio import SocketIO, emit
import pandas as pd
import math

app = Flask(__name__)
app.config['SECRET_KEY'] = 'secret!'

socketio = SocketIO(app, cors_allowed_origins="*")

# Live user locations
live_locations = {}

# Define danger zones as circular areas
DANGER_ZONES = [
    {"center": (26.1, 91.7), "radius_km": 5},   # Guwahati
    {"center": (27.0, 94.0), "radius_km": 5},   # Arunachal area
    {"center": (24.8, 92.7), "radius_km": 5},   # Meghalaya area
]

def haversine(lat1, lon1, lat2, lon2):
    """Calculate distance between two lat/lon points in km."""
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    return R * c

def is_in_danger_zone(lat, lon):
    """Check if the location is inside any danger zone."""
    for zone in DANGER_ZONES:
        center_lat, center_lon = zone["center"]
        if haversine(lat, lon, center_lat, center_lon) <= zone["radius_km"]:
            return True
    return False

# Serve HTML
@app.route("/")
def index():
    return render_template("map.html")

# API to get static heatmap points
@app.route("/api/heatpoints")
def get_heatpoints():
    df = pd.read_csv("heatpoints.csv")
    return jsonify(df.to_dict(orient="records"))

# API for dashboard counts
@app.route("/api/dashboard")
def dashboard_data():
    danger_count = sum(1 for u in live_locations.values() if u["in_danger"])
    safe_count = len(live_locations) - danger_count
    return jsonify({
        "safe": safe_count,
        "danger": danger_count,
        "total": len(live_locations)
    })

# WebSocket location updates
@socketio.on('location_update')
def handle_location_update(data):
    lat = data['lat']
    lon = data['lon']

    in_danger = is_in_danger_zone(lat, lon)

    live_locations[data['user_id']] = {
        "lat": lat,
        "lon": lon,
        "in_danger": in_danger
    }

    # Broadcast to all clients
    emit('location_broadcast', data, broadcast=True)

if __name__ == "__main__":
    print("Starting Flask-SocketIO server...")
    socketio.run(app, host="0.0.0.0", port=5000, debug=True)
