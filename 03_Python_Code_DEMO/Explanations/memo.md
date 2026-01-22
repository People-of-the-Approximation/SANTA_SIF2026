## URL addr
```
http://localhost:8000/attention_ui`
```

## 실행
```
cd 03_Python_Code_DEMO
python app.py
```

## pip 설치
```
python -m pip install fastapi uvicorn python-multipart
python -m pip install torch transformers datasets
python -m pip install numpy matplotlib
python -m pip install pyserial
```

### 만약 `gpt heatmap`이 `err`로 나오는 경우 버전 교체하기
```
pip install -U "transformers==4.53.1"
```