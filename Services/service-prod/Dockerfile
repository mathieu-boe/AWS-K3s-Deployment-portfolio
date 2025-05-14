# services/service-prod/Dockerfile
FROM python:3.11-slim

WORKDIR /service-prod

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]