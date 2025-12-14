import jwt
import os
from fastapi import Request, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM")

def decode_jwt(token: str) -> dict:
    """
    Decode and verify JWT token.
    Only accepts ACCESS tokens (not refresh tokens).
    Returns decoded payload if valid, None otherwise.
    """
    try:
        decoded_token = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        
        # CRITICAL: Only accept access tokens on resource endpoints
        if decoded_token.get("type") != "access":
            return None
        
        # Check expiry
        return decoded_token if decoded_token.get("expiry", 0) >= __import__('time').time() else None
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

class JWTBearer(HTTPBearer):
    """
    FastAPI dependency for JWT authentication.
    
    Usage:
        @app.get("/protected", dependencies=[Depends(JWTBearer())])
        async def protected_route():
            ...
    
    Or to access user info:
        @app.get("/protected")
        async def protected_route(credentials: dict = Depends(JWTBearer())):
            user_id = credentials["user_id"]
            role = credentials["role"]
            ...
    """
    
    def __init__(self, auto_error: bool = True):
        super(JWTBearer, self).__init__(auto_error=auto_error)

    async def __call__(self, request: Request):
        credentials: HTTPAuthorizationCredentials = await super(JWTBearer, self).__call__(request)
        
        if credentials:
            if not credentials.scheme == "Bearer":
                raise HTTPException(status_code=403, detail="Invalid authentication scheme.")
            
            payload = self.verify_jwt(credentials.credentials)
            if not payload:
                raise HTTPException(status_code=403, detail="Invalid token or expired token.")
            
            return payload  # Return decoded payload (user_id, role, expiry)
        else:
            raise HTTPException(status_code=403, detail="Invalid authorization code.")

    def verify_jwt(self, jwtoken: str) -> dict:
        """Verify and decode the JWT token."""
        payload = decode_jwt(jwtoken)
        return payload if payload else None
