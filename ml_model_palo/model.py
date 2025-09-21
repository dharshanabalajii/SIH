import numpy as np
import pandas as pd
import random
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier, export_text, plot_tree
from sklearn.metrics import accuracy_score, classification_report
import matplotlib.pyplot as plt
import joblib



# ---------------------------
# Generate Data
# ---------------------------
data = pd.read_csv("sensor_data.csv")
print("Dataset loaded")

# ---------------------------
# Prepare Features and Target
# ---------------------------
X = data[['temperature', 'heartbeat', 'sos', 'latitude', 'longitude']]
y = data['risk']

# Split into train/test sets
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# ---------------------------
# Train Decision Tree
# ---------------------------
model = DecisionTreeClassifier(max_depth=4, random_state=42)
model.fit(X_train, y_train)

# ---------------------------
# Evaluate the Model
# ---------------------------
y_pred = model.predict(X_test)

print("model going to dump")
joblib.dump(model, "risk_model.pkl")
print("model dumped")

accuracy = accuracy_score(y_test, y_pred)
print(f"Accuracy: {accuracy:.2f}")
print("\nClassification Report:\n", classification_report(y_test, y_pred))

# ---------------------------
# Visualize the Tree
# ---------------------------
plt.figure(figsize=(18, 8))
plot_tree(model, feature_names=X.columns, class_names=['No Risk', 'Risk'], filled=True)
plt.title("Decision Tree Visualization")
plt.show()

# ---------------------------
# Print the Tree Rules
# ---------------------------
tree_rules = export_text(model, feature_names=list(X.columns))
print("\nDecision Tree Rules:\n")
print(tree_rules)

