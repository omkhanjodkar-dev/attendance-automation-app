import time
import jwt
import os
import secrets

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))

def token_response(access_token: str, refresh_token: str):
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer"
    }

def sign_jwt(user_id: str, role: str):
    # Generate short-lived access token
    access_payload = {
        "user_id": user_id,
        "role": role,
        "expiry": time.time() + ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        "type": "access"
    }
    access_token = jwt.encode(access_payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    
    # Generate long-lived refresh token with unique ID
    refresh_payload = {
        "user_id": user_id,
        "role": role,
        "expiry": time.time() + REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60,
        "type": "refresh",
        "jti": secrets.token_urlsafe(32)  # Unique token ID
    }
    refresh_token = jwt.encode(refresh_payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    
    return token_response(access_token, refresh_token)

def decode_token(token: str):
    try:
        decoded_token = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return decoded_token if decoded_token.get("expiry", 0) >= time.time() else None
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

