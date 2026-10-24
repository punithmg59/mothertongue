# MotherTongue Translation Backend

FastAPI backend for the MotherTongue Flutter app, providing secure translation services using Sarvam AI API.

## Overview

This backend server:
- Accepts translation requests from the Flutter app
- Calls Sarvam AI translation API securely
- Preserves mathematical content (numbers, equations, operators)
- Handles errors gracefully with appropriate HTTP status codes
- Never exposes API keys in responses or logs

## Prerequisites

- Python 3.8 or higher
- pip package manager
- Sarvam AI API key

## Installation

1. **Navigate to the backend directory:**
   ```bash
   cd backend
   ```

2. **Create a virtual environment (recommended):**
   ```bash
   python -m venv venv
   
   # Windows
   venv\Scripts\activate
   
   # Linux/Mac
   source venv/bin/activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables:**
   ```bash
   # Copy the example file
   copy .env.example .env  # Windows
   # or
   cp .env.example .env  # Linux/Mac
   
   # Edit .env and add your Sarvam API key
   # SARVAM_API_KEY=your_actual_api_key_here
   ```

## Running the Backend

### Development Mode

```bash
# Using uvicorn directly
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Or using Python
python main.py
```

The server will start on `http://0.0.0.0:8000`

### Production Mode

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

## API Endpoints

### GET `/`

Root endpoint with API information.

**Response:**
```json
{
  "service": "MotherTongue Translation API",
  "version": "1.0.0",
  "status": "running",
  "endpoints": {
    "translate": "/translate",
    "health": "/health"
  }
}
```

### GET `/health`

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "sarvam_configured": true
}
```

### POST `/translate`

Main translation endpoint.

**Request Body:**
```json
{
  "text_blocks": [
    {
      "text": "प्रकाश संश्लेषण",
      "x": 10.0,
      "y": 20.0,
      "width": 100.0,
      "height": 30.0
    }
  ],
  "source_language": "hi-IN",
  "target_language": "kn-IN"
}
```

**Response:**
```json
{
  "translated_blocks": [
    {
      "text": "ದ್ಯುತಿ ಸಂಶ್ಲೇಷಣೆ",
      "x": 10.0,
      "y": 20.0,
      "width": 100.0,
      "height": 30.0
    }
  ],
  "source_language": "hi-IN",
  "target_language": "kn-IN",
  "processing_time_ms": 250.5
}
```

## Supported Languages

- **Hindi**: `hi-IN`
- **English**: `en-IN`
- **Kannada**: `kn-IN`
- **Tamil**: `ta-IN`
- **Telugu**: `te-IN`
- **Malayalam**: `ml-IN`
- **Marathi**: `mr-IN`
- **Bengali**: `bn-IN`
- **Gujarati**: `gu-IN`
- **Punjabi**: `pa-IN`
- **Odia**: `or-IN`

## Mathematical Content Preservation

The backend automatically preserves mathematical expressions:
- Numbers: `2 + 2 = 4`
- Variables: `x + y = z`
- Operators: `+`, `-`, `*`, `/`, `=`
- Parentheses: `(a + b)`
- Decimals: `1.5 + 2.5`

These are returned unchanged without translation.

## Error Handling

The backend returns appropriate HTTP status codes:

- `400`: Bad Request (e.g., empty text blocks)
- `401`: Unauthorized (Sarvam API key invalid)
- `503`: Service Unavailable (network error)
- `504`: Gateway Timeout (Sarvam API timeout)
- `500`: Internal Server Error (unexpected errors)

Error responses never expose API keys or sensitive information.

## Testing

### Run Unit Tests

```bash
pytest test_main.py -v
```

### Test Coverage

Tests include:
- Mathematical content detection
- Health endpoint
- Root endpoint
- Translation with mocked Sarvam API
- Empty text blocks handling
- Multiple text blocks
- Sarvam API timeout handling
- Sarvam API error handling

All tests use mocked responses - no actual API calls are made during testing.

## Connecting Flutter App

### For Android Emulator

The Flutter app is configured to use `http://10.0.2.2:8000` by default, which is the special IP address for the host machine from the Android emulator.

### For Physical Android Device

1. **Find your computer's IP address:**
   ```bash
   # Windows
   ipconfig
   
   # Linux/Mac
   ifconfig
   ```

2. **Update Flutter .env file:**
   ```
   BACKEND_URL=http://YOUR_COMPUTER_IP:8000
   ```
   Example: `BACKEND_URL=http://192.168.1.100:8000`

3. **Ensure both devices are on the same network**

4. **Allow firewall access:**
   - Windows: Allow Python through Windows Firewall
   - Linux: Configure ufw if needed

### For iOS Simulator

Use `http://localhost:8000` or your computer's IP.

## Deployment

### Using Docker (Optional)

Create a `Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Build and run:
```bash
docker build -t mothertongue-backend .
docker run -p 8000:8000 --env-file .env mothertongue-backend
```

### Using systemd (Linux)

Create a service file `/etc/systemd/system/mothertongue-backend.service`:
```ini
[Unit]
Description=MotherTongue Translation Backend
After=network.target

[Service]
Type=simple
User=your_user
WorkingDirectory=/path/to/backend
Environment="PATH=/path/to/backend/venv/bin"
ExecStart=/path/to/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable mothertongue-backend
sudo systemctl start mothertongue-backend
```

## Security Considerations

1. **Never commit `.env` file** - it's in `.gitignore`
2. **Use HTTPS in production** - configure SSL/TLS
3. **Restrict CORS origins** - update `allow_origins` in production
4. **Rate limiting** - consider adding rate limiting for production
5. **API key rotation** - rotate Sarvam API keys periodically
6. **Monitor logs** - check for unusual activity

## Troubleshooting

### Backend won't start

- Check if port 8000 is already in use
- Verify Python version is 3.8+
- Ensure all dependencies are installed

### Flutter app can't connect

- Verify backend is running: `curl http://localhost:8000/health`
- Check firewall settings
- For physical device: ensure both devices on same network
- Verify IP address in Flutter .env file

### Translation fails

- Check Sarvam API key is valid
- Verify Sarvam API account has credits
- Check backend logs for errors
- Test Sarvam API directly using curl

### CORS errors

- Verify CORS middleware is configured
- Check `allow_origins` setting
- For production, specify exact origins instead of `*`

## API Documentation

When the backend is running, access the interactive API documentation:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## License

This backend is part of the MotherTongue project.
