import serial
import requests

# Adjust to your ESP2 serial port and baud rate
ser = serial.Serial('COM5', 115200)  # Use '/dev/ttyUSB0' on Linux/Mac

while True:
    try:
        if ser.in_waiting:
            print("hi")
            line = ser.readline().decode().strip()
            print(f"Received from LoRa: {line}")
            requests.post("http://127.0.0.1:5000/update", json={"data": line})
            print("hello")
    except Exception as e:
        print("Error:", e) 