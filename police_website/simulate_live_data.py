import socketio
import random
import time

# Connect to Flask WebSocket
sio = socketio.Client()
sio.connect('http://localhost:5000')

# NE India boundaries
BOUNDARIES = {
    "min_lat": 23.5,
    "max_lat": 28.5,
    "min_lon": 89.5,
    "max_lon": 96.0
}

# Hotspot centers
HOTSPOTS = [
    (26.1, 91.7),
    (27.0, 94.0),
    (24.8, 92.7)
]

TOTAL_USERS = 50
CLUSTERED_USERS = int(TOTAL_USERS * 0.4)
FREE_USERS = TOTAL_USERS - CLUSTERED_USERS

users = {}

# Initialize users
for i in range(TOTAL_USERS):
    if i < CLUSTERED_USERS:
        # Near hotspots
        hotspot = random.choice(HOTSPOTS)
        lat = random.uniform(hotspot[0] - 0.05, hotspot[0] + 0.05)
        lon = random.uniform(hotspot[1] - 0.05, hotspot[1] + 0.05)
    else:
        # Random across region
        lat = random.uniform(BOUNDARIES["min_lat"], BOUNDARIES["max_lat"])
        lon = random.uniform(BOUNDARIES["min_lon"], BOUNDARIES["max_lon"])

    speed = random.choice([
        random.uniform(0.0003, 0.0008),  # Walking
        random.uniform(0.0008, 0.0015),  # Running
        random.uniform(0.0015, 0.0030)   # Vehicle
    ])

    users[f"user{i+1}"] = {"lat": lat, "lon": lon, "speed": speed, "clustered": i < CLUSTERED_USERS}

def keep_within_bounds(lat, lon):
    if lat < BOUNDARIES["min_lat"]: lat = BOUNDARIES["min_lat"] + 0.0005
    if lat > BOUNDARIES["max_lat"]: lat = BOUNDARIES["max_lat"] - 0.0005
    if lon < BOUNDARIES["min_lon"]: lon = BOUNDARIES["min_lon"] + 0.0005
    if lon > BOUNDARIES["max_lon"]: lon = BOUNDARIES["max_lon"] - 0.0005
    return lat, lon

while True:
    for user_id, data in users.items():
        lat, lon = data["lat"], data["lon"]

        if data["clustered"]:
            lat_change = random.uniform(-1, 1) * (data["speed"] * 0.5)
            lon_change = random.uniform(-1, 1) * (data["speed"] * 0.5)
        else:
            lat_change = random.uniform(-1, 1) * data["speed"]
            lon_change = random.uniform(-1, 1) * data["speed"]

        new_lat = lat + lat_change
        new_lon = lon + lon_change
        new_lat, new_lon = keep_within_bounds(new_lat, new_lon)

        data["lat"], data["lon"] = new_lat, new_lon

        sio.emit('location_update', {
            "user_id": user_id,
            "lat": new_lat,
            "lon": new_lon
        })

    time.sleep(1)
