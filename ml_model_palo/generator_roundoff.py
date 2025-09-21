import pandas as pd
import numpy as np
import random

def generate_sensor_data(n_samples=1000, seed=42):
    """
    Generate synthetic sensor data for decision tree training.
    Features:
      - temperature (°C)
      - heartbeat (bpm)
      - sos (0/1)
      - latitude (approx region)
      - longitude (approx region)
    Target:
      - risk (0/1)
    """
    np.random.seed(seed)
    random.seed(seed)
    
    # Temperature: normal range 36-38°C, high risk if > 39°C
    temperature = np.random.normal(loc=37, scale=1.5, size=n_samples)
    
    # Heartbeat: normal 60-100 bpm, high risk if <50 or >120
    heartbeat = np.random.normal(loc=80, scale=15, size=n_samples)
    
    # SOS: mostly 0, sometimes 1
    sos = np.random.choice([0, 1], size=n_samples, p=[0.9, 0.1])
    
    # Latitude and Longitude: random location around a region
    latitude = np.random.uniform(low=12.8, high=13.2, size=n_samples)  # Example: Bangalore area
    longitude = np.random.uniform(low=77.5, high=77.8, size=n_samples)
    
    # Round to 2 decimal places
    temperature = np.round(temperature, 2)
    heartbeat = np.round(heartbeat, 2)
    latitude = np.round(latitude, 2)
    longitude = np.round(longitude, 2)
    
    # Risk determination logic (purposeful for decision tree)
    risk = []
    for t, h, s in zip(temperature, heartbeat, sos):
        if s == 1:
            risk.append(1)  # SOS signal is always high risk
        elif t > 39 or h < 50 or h > 120:
            risk.append(1)  # High fever or abnormal heartbeat
        else:
            risk.append(0)
    
    # Create DataFrame
    df = pd.DataFrame({
        'temperature': temperature,
        'heartbeat': heartbeat,
        'sos': sos,
        'latitude': latitude,
        'longitude': longitude,
        'risk': risk
    })

    return df

# Example usage and save to CSV
data = generate_sensor_data(n_samples=1000)
data.to_csv("sensor_data.csv", index=False)
print("Dataset saved as sensor_data.csv")
