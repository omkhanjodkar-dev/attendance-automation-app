import time
import jwt
import os

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM")
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "60"))

def token_response(token: str):
    return {
        "access_token" : token
    }

def sign_jwt(user_id: str, role: str):
    payload = {
        "user_id": user_id,
        "role": role,
        "expiry": time.time() + JWT_EXPIRE_MINUTES * 60
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

    return token_response(token)

def decode_token(token: str):
    try:
        decoded_token = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return decoded_token if decoded_token["expiry"] >= time.time() else None
    except:
        return {}

