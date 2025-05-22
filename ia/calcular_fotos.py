from collections import Counter
import os

label_dir = "dataset/labels/train"

counter = Counter()

for file in os.listdir(label_dir):
    if file.endswith(".txt"):
        classes_in_file = set()
        with open(os.path.join(label_dir, file), "r") as f:
            for line in f:
                class_id = line.strip().split()[0]
                classes_in_file.add(class_id)
        for class_id in classes_in_file:
            counter[class_id] += 1

id2name = {
    "0": "buraco",
    "1": "contaminado",
    "2": "mofo",
    "3": "pao",
    "4": "queimado"
}


for class_id, count in counter.items():
    print(f"{id2name[class_id]}: {count} imagens")

#yolo detect train model=yolov8n.pt data=dataset/data.yaml epochs=300 imgsz=640 batch=8 augment=True patience=50 name=defeitos_paes_v3
