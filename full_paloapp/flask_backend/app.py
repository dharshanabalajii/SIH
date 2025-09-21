from flask import Flask, request, jsonify
from geopy.distance import geodesic

app = Flask(__name__)

# Define your geofence center (e.g., school/house location)
GEOFENCE_CENTER = (12.9715987, 77.5945627)  # Example: Bangalore
GEOFENCE_RADIUS_METERS = 100  # 100 meter radius

@app.route('/check_geofence', methods=['POST'])
def check_geofence():
    data = request.get_json()
    user_lat = data.get('latitude')
    user_lng = data.get('longitude')

    if user_lat is None or user_lng is None:
        return jsonify({'error': 'Missing latitude or longitude'}), 400

    user_location = (user_lat, user_lng)
    distance = geodesic(GEOFENCE_CENTER, user_location).meters

    inside = distance <= GEOFENCE_RADIUS_METERS
    return jsonify({
        'inside_geofence': inside,
        'distance_meters': distance
    })

if __name__ == '__main__':
    app.run(debug=True)
