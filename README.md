# yolov8-real-time

## YOLOv8 模型导出为 CoreML 格式

```python
from ultralytics import YOLO

# Load a model
model = YOLO('yolov8s.pt')  # load an official model

# Export the model
model.export(format='coreml', nms=True)
```

[yolov8s.mlpackage](https://drive.google.com/drive/folders/1fe1LG-Q8E92YZGfS0ltTy_nYqOx7DAI9?usp=sharing)