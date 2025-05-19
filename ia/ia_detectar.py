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

model = YOLO("runs/detect/train/weights/best.pt")  

@app.post("/detect")
async def detect_defects(image: UploadFile = File(...)):
    image_data = await image.read()
    pil_image = Image.open(io.BytesIO(image_data)).convert("RGB")

    results = model(pil_image)[0]  

    boxes = []
    for box in results.boxes.data.tolist():
        x1, y1, x2, y2, score, class_id = box
        boxes.append({
            "x": x1,
            "y": y1,
            "width": x2 - x1,
            "height": y2 - y1,
            "label": results.names[int(class_id)],
            "confidence": round(score * 100, 1) 
        })

    return JSONResponse(content=boxes)

#http://localhost:8000/detect


