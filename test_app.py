#!/usr/bin/env python3
"""
Test suite for Healthcare Prediction API
"""

import pytest
import asyncio
from fastapi.testclient import TestClient
from app import app

client = TestClient(app)


class TestHealthcareAPI:
    """Test suite for all API endpoints"""

    def test_root_endpoint(self):
        """Test the root endpoint"""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "Healthcare Prediction API" in data["message"]
        assert "endpoints" in data

    def test_health_check(self):
        """Test the health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        
        # Verify required fields
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert "uptime_seconds" in data
        assert data["service"] == "healthcare-prediction-api"
        assert data["version"] == "1.0.0"
        
        # Verify data types
        assert isinstance(data["uptime_seconds"], (int, float))
        assert isinstance(data["timestamp"], (int, float))

    def test_predict_endpoint(self):
        """Test the prediction endpoint"""
        response = client.get("/predict")
        assert response.status_code == 200
        data = response.json()
        
        # Verify required fields
        assert "score" in data
        assert "confidence" in data
        assert "model_version" in data
        assert "timestamp" in data
        
        # Verify data constraints
        assert 0.0 <= data["score"] <= 1.0
        assert 0.0 <= data["confidence"] <= 1.0
        assert isinstance(data["timestamp"], (int, float))

    def test_metrics_endpoint(self):
        """Test the metrics endpoint"""
        # First make some requests to generate metrics
        client.get("/health")
        client.get("/predict")
        
        response = client.get("/metrics")
        assert response.status_code == 200
        assert "text/plain" in response.headers["content-type"]
        
        # Check if metrics are present
        content = response.text
        assert "api_requests_total" in content
        assert "api_request_duration_seconds" in content

    def test_multiple_predict_calls(self):
        """Test multiple prediction calls for consistency"""
        scores = []
        for _ in range(5):
            response = client.get("/predict")
            assert response.status_code == 200
            scores.append(response.json()["score"])
        
        # Verify all scores are valid
        for score in scores:
            assert 0.0 <= score <= 1.0

    def test_health_check_multiple_calls(self):
        """Test health check stability over multiple calls"""
        for _ in range(3):
            response = client.get("/health")
            assert response.status_code == 200
            assert response.json()["status"] == "healthy"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])