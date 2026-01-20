#!/usr/bin/env python3
"""
Healthcare API Service
A simple FastAPI service with health and prediction endpoints
"""

import os
import time
from typing import Dict, Any
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
from prometheus_client import Counter, Histogram, generate_latest
from starlette.responses import Response
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('api_requests_total', 'Total API requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('api_request_duration_seconds', 'Request duration')

app = FastAPI(
    title="Healthcare Prediction API",
    description="A simple healthcare prediction service with monitoring capabilities",
    version="1.0.0",
    contact={
        "name": "DevOps Team",
        "email": "devops@healthcare.com"
    }
)

# CORS middleware for production use
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual domains
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# Application state
app_start_time = time.time()


@app.middleware("http")
async def metrics_middleware(request, call_next):
    """Middleware to collect metrics for each request"""
    start_time = time.time()
    
    response = await call_next(request)
    
    # Record metrics
    duration = time.time() - start_time
    REQUEST_DURATION.observe(duration)
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    return response


@app.get("/health")
async def health_check() -> Dict[str, Any]:
    """
    Health check endpoint
    Returns the service health status and uptime
    """
    try:
        uptime = time.time() - app_start_time
        
        # Simulate some basic health checks
        health_status = {
            "status": "healthy",
            "timestamp": time.time(),
            "uptime_seconds": round(uptime, 2),
            "service": "healthcare-prediction-api",
            "version": "1.0.0"
        }
        
        logger.info("Health check successful")
        return health_status
        
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        raise HTTPException(status_code=503, detail="Service unhealthy")


@app.get("/predict")
async def predict() -> Dict[str, float]:
    """
    Prediction endpoint
    Returns a mock prediction score for healthcare analytics
    """
    try:
        # Simulate prediction logic
        # In a real scenario, this would call ML models or analytics engines
        import random
        
        # Generate a realistic healthcare score between 0.1 and 0.95
        prediction_score = round(random.uniform(0.1, 0.95), 2)
        
        result = {
            "score": prediction_score,
            "confidence": round(random.uniform(0.8, 0.99), 2),
            "model_version": "v1.2.0",
            "timestamp": time.time()
        }
        
        logger.info(f"Prediction generated: {result}")
        return result
        
    except Exception as e:
        logger.error(f"Prediction failed: {str(e)}")
        raise HTTPException(status_code=500, detail="Prediction service error")


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type="text/plain")


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Healthcare Prediction API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "predict": "/predict",
            "metrics": "/metrics",
            "docs": "/docs"
        }
    }


if __name__ == "__main__":
    # Get port from environment variable or default to 8000
    port = int(os.getenv("PORT", 8000))
    
    logger.info(f"Starting Healthcare Prediction API on port {port}")
    
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=port,
        log_level="info",
        access_log=True
    )