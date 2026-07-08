import pandas as pd
import matplotlib.pyplot as plt
import os

df = pd.read_csv("trocr_model/training_log.csv")

# 🔴 เอาเฉพาะแถวที่มี train_loss
df = df.dropna(subset=["train_loss"])

os.makedirs("results", exist_ok=True)

plt.figure()
plt.plot(
    df["epoch"],
    df["train_loss"],
    marker="o",
    linewidth=2,
    label="Training Loss"
)

plt.xlabel("Epoch")
plt.ylabel("Loss")
plt.title("Training Loss Curve (TrOCR)")
plt.grid(True)
plt.legend()

plt.savefig("results/loss_curve.png")
plt.close()

print("✅ Saved results/loss_curve.png")