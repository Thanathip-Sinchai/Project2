# Installation

## 1. Clone project

```bash
git clone https://github.com/Thanathip-Sinchai/Project2.git

2. Install dependencies
pip install -r requirements.txt
flutter pub get

3. Download trained model and dataset
Download from Google Drive:
Dataset
TrOCR CPU Model
TrOCR GPU Model
https://drive.google.com/drive/folders/1V5A1d3_DUk0D4DiAO1iRUi_fz-4JFEtE?usp=sharing
Extract to:
trocr_dbnet_pipeline/trocr_full_pipeline/

so the structure becomes:
trocr_full_pipeline/
├── data/
├── trocr_model/
├── trocr_model_gpu/
├── models/
└── ...

4. Run the project
