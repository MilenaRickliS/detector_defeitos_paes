#uvicorn ia_detectar:app --reload --host 0.0.0.0

from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from ultralytics import YOLO
from PIL import Image
import io


app = FastAPI()


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


model = YOLO("runs/detect/defeitos_paes_v3/weights/best.pt")  


@app.post("/detect")
async def detect_defects(image: UploadFile = File(...)):
    image_data = await image.read()
    pil_image = Image.open(io.BytesIO(image_data)).convert("RGB")


    results = model(pil_image)[0]


    # Thresholds personalizados por classe
    class_thresholds = {
        "pao": 0.5,
        "buraco": 0.3,
        "contaminado": 0.3,
        "queimado": 0.4,
        "mofo": 0.4,
    }


    boxes = []
    for box in results.boxes.data.tolist():
        x1, y1, x2, y2, score, class_id = box
        class_name = results.names[int(class_id)]
        threshold = class_thresholds.get(class_name, 0.5) 

        if score >= threshold:
            boxes.append({
                "x": x1,
                "y": y1,
                "width": x2 - x1,
                "height": y2 - y1,
                "label": class_name,
                "confidence": round(score * 100, 1)
            })


    return JSONResponse(content=boxes)




#http://localhost:8000/detect
