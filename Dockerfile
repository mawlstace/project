FROM python:3.9-slim-buster

# installing trivy to check Docker image vulernabilite 
RUN apt-get update && \
    apt-get install -y wget lsb-release && \
    wget https://github.com/aquasecurity/trivy/releases/download/v0.20.0/trivy_0.20.0_Linux-64bit.tar.gz && \
    tar zxvf trivy_0.20.0_Linux-64bit.tar.gz && \
    mv trivy /usr/local/bin/

# Copy the application files
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

# Install Nginx and copy the configuration file
RUN apt-get update && \
    apt-get install -y nginx
COPY nginx.conf /etc/nginx/sites-available/default

# Start Nginx and run the Flask application with Trivy
CMD service nginx start && \
    trivy --no-progress --exit-code 0 --severity CRITICAL,HIGH,MEDIUM python:3.9-slim-buster && \
    python app.py
