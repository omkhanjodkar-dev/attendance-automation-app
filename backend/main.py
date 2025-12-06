import uvicorn
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field
from typing import List, Optional, Literal
from datetime import datetime
import random
import requests
from datetime import datetime, timedelta
import json


# Initialize the application
app = FastAPI(
    title="Attendance Automation App",
    description="A simple app for marking your college attendance.",
    version="2.3"
)

# --- Pydantic Models for Data Validation ---

class StockAnalysis(BaseModel):
    symbol: str
    recommendation: Literal["BUY", "SELL", "HOLD"]
    confidence_score: float
    analysis_date: datetime
    summary: str

class StockDetails(BaseModel):
    symbol: str
    company_name: str
    current_price: float
    sector: str
    pe_ratio: Optional[float] = None

class PortfolioPosition(BaseModel):
    symbol: str
    quantity: int
    average_price: float
    current_value: float

class AuditLog(BaseModel):
    id: str
    action: str
    timestamp: datetime
    details: str

class OrderRequest(BaseModel):
    symbol: str
    side: Literal["buy", "sell"]
    quantity: int = Field(..., gt=0, description="Must be a positive integer")
    order_type: Literal["market", "limit"]
    limit_price: Optional[float] = None

class OrderResponse(BaseModel):
    order_id: str
    status: str
    message: str
    timestamp: datetime

# --- Mock Data ---

PORTFOLIO = [
    {"symbol": "AAPL", "quantity": 10, "average_price": 150.00, "current_value": 1750.00},
    {"symbol": "GOOGL", "quantity": 5, "average_price": 2800.00, "current_value": 14500.00},
    {"symbol": "MSFT", "quantity": 15, "average_price": 300.00, "current_value": 4800.00}
]

AUDIT_LOGS = [
    {"id": "log_001", "action": "LOGIN", "timestamp": datetime.now(), "details": "User logged in"},
    {"id": "log_002", "action": "VIEW_PORTFOLIO", "timestamp": datetime.now(), "details": "Portfolio accessed"},
]

# --- API Endpoints ---

@app.get("/", tags=["General"])
async def root():
    return {"message": "Stock Trading Agent API is running. Visit /docs for Swagger UI."}

@app.get("/get_agent_analysis", response_model=StockAnalysis, tags=["Analysis"])
async def get_agent_analysis(symbol: str = Query(..., description="Stock symbol to analyze")):
    return super_agent(symbol)

@app.get("/get_details_search_stock", response_model=StockDetails, tags=["Market Data"])
async def get_details_search_stock(query: str):
    return get_direct_stock_details(query)

@app.get("/get_portfolio", response_model=List[PortfolioPosition], tags=["Account"])
async def get_portfolio():
    url = f"{BASE_URL}/positions"
    headers = {
        "APCA-API-KEY-ID": ALPACA_API_KEY,
        "APCA-API-SECRET-KEY": ALPACA_SECRET_KEY
    }
    response = requests.get(url, headers=headers)
    return response.json()

@app.get("/get_audit", response_model=List[AuditLog], tags=["Compliance"])
async def get_audit(limit: int = 10):
    """
    Get system audit logs.
    """
    return AUDIT_LOGS[:limit]

@app.post("/post_order", response_model=OrderResponse, tags=["Trading"])
async def post_order(order: OrderRequest):
    """
    Place a new buy or sell order.
    """
    # Logic to validate order would go here (e.g., check funds, market status)
    
    order_id = f"ord_{random.randint(1000, 9999)}"
    
    # Add to audit log (mock side effect)
    AUDIT_LOGS.append({
        "id": f"log_{random.randint(1000, 9999)}",
        "action": "ORDER_PLACED",
        "timestamp": datetime.now(),
        "details": f"{order.side.upper()} {order.quantity} {order.symbol}"
    })
    
    return {
        "order_id": order_id,
        "status": "filled",
        "message": f"Successfully processed {order.side} order for {order.quantity} shares of {order.symbol}",
        "timestamp": datetime.now()
    }

# --- Server Entry Point ---

if __name__ == "__main__":
    # This allows you to run the file directly: python server.py
    print("Starting server on http://localhost:8000")
    print("Documentation available at http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)