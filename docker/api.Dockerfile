FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies first so Docker can cache this layer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the app code
COPY . .

# Swap the client's name for a demo name (see the note below)
ARG CLIENT_NAME
RUN if [ -n "$CLIENT_NAME" ]; then \
    grep -rlI "$CLIENT_NAME" --exclude-dir=node_modules . \
    | xargs -r sed -i "s/$CLIENT_NAME S\.A\.S\.\{0,1\}/Empresa Demo S.A.S./g; s/AUD-$CLIENT_NAME/AUD-DEMO/g"; \
    fi

# Run as a normal user, not root
RUN chmod -R a+rX /app
RUN useradd --create-home appuser
USER appuser

EXPOSE 8000
CMD ["uvicorn", "api.index:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*"]