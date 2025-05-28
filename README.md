
# 🥖 Detector de Defeitos em Pães

Este projeto utiliza **YOLOv8**, **FastAPI** e **Flutter** para detectar defeitos em pães por meio de imagens. A aplicação é composta por uma **API Python** com um modelo de visão computacional e um **app Flutter** que permite capturar a imagem do pão e visualizar os defeitos detectados.

---

## 🔍 Funcionalidades

- 📷 Tirar foto de um pão ou buscar na galeria pelo app Flutter
- 🧠 Enviar a imagem para uma API com modelo YOLOv8 treinado
- 📦 Detectar e classificar defeitos como:
  - buraco
  - contaminado
  - queimado
  - mofo
  - pão (normal)
- 🖼️ Exibir resultados com marcações visuais e informações de confiança

---

## 🧠 Modelo YOLOv8

O modelo YOLOv8 foi treinado usando imagens anotadas de pães com defeitos. Ele é carregado na API com o caminho:

```python
model = YOLO("runs/detect/defeitos_paes_v3/weights/best.pt")
```

## 🚀 Como executar o projeto

### 1. Clone o projeto

```bash
git clone https://github.com/MilenaRickliS/detector_defeitos_paes.git
```

### 2. Crie o ambiente e instale as dependências

```bash
cd ia
python -m venv venv
source venv/bin/activate  # Linux/macOS
venv\Scripts\activate     # Windows

pip install -r requirements.txt
```

### 3. Inicie o servidor

```bash
uvicorn ia_detectar:app --reload --host 0.0.0.0 --port 8000
```

### 4. Rode o flutter

```bash
cd lib
flutter pub get
flutter run
```

### 5. Atualize o IP no main.dart

```bash
Uri.parse('http://<SEU-IP-AQUI>:8000/detect') (linha 101)
```

---

## 📲 Aplicativo Flutter

O app Flutter permite:

- Capturar uma imagem com a câmera ou escolher imagem da galeria
- Corrigir orientação da imagem
- Enviar a imagem para a API `/detect`
- Exibir a imagem com bounding boxes e lista de defeitos detectados

### Dependências principais no `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  image_picker: ^1.1.2
  http: ^1.4.0
  flutter_exif_rotation: ^0.5.2
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_launcher_icons: ^0.14.3
  flutter_native_splash: ^2.4.6
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/icons/
```
---
## 📦 API

- Desenvolvida com FastAPI
- Utiliza o modelo YOLOv8 (You Only Look Once v8)
- Rota principal: POST /detect
- Responsável por:
  - Receber a imagem 
  - Rodar detecção
  - Filtrar os resultados com base na confiança mínima por classe
  - Retornar JSON com as detecções 

---
Cada classe possui um **limiar mínimo de confiança personalizada** para reduzir falsos positivos:

```python
class_thresholds = {
  "pao": 0.5,
  "buraco": 0.3,
  "contaminado": 0.3,
  "queimado": 0.4,
  "mofo": 0.3,
}
```

```Exemplo de resposta JSON
[
  {
    "x": 120.0,
    "y": 85.0,
    "width": 60.0,
    "height": 45.0,
    "label": "mofo",
    "confidence": 91.2
  },
  {
    "x": 200.0,
    "y": 100.0,
    "width": 55.0,
    "height": 50.0,
    "label": "queimado",
    "confidence": 87.5
  }
]
```
---

## 🔗 Estrutura do Projeto

```
detector_defeitos_paes/
├── ia/
│   ├── ia_detectar.py                 # API com FastAPI e YOLOv8
│   ├── dataset/                       # Pasta com imagens e labels
│   └── runs/detect/defeitos_paes_v3/  # Pesos do modelo YOLOv8 (.pt)
├── assets/icons/                      # Ícone do app Flutter
└── lib/                               # Código Flutter
```

---

## 🙋‍♀️ Desenvolvedora

**Milena Rickli Silvério Kriger**  
🔗 [GitHub](https://github.com/MilenaRickliS/detector_defeitos_paes.git)
