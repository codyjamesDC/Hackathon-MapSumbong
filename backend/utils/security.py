import os
import time
from collections import defaultdict, deque
from typing import Any, Callable

import jwt
from fastapi import Depends, Header, HTTPException
from fastapi.responses import JSONResponse


RATE_LIMIT_REQUESTS = int(os.getenv('RATE_LIMIT_REQUESTS', '60'))
RATE_LIMIT_WINDOW_SEC = int(os.getenv('RATE_LIMIT_WINDOW_SEC', '60'))


def _get_jwt_settings() -> tuple[str, str]:
    """Read JWT settings at call time so env changes are reflected immediately."""
    algorithm = os.getenv('JWT_ALGORITHM', 'HS256')
    secret = os.getenv('JWT_SECRET', '')
    return algorithm, secret


def _extract_bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(status_code=401, detail='Missing Authorization header')
    if not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail='Invalid Authorization scheme')
    return authorization.split(' ', 1)[1].strip()


def verify_jwt_token(token: str) -> dict[str, Any]:
    """
    Validate JWT and return decoded claims.
    Accepts custom tokens with `role`, or Supabase user JWTs (`role: authenticated`).
    Optional `app_metadata.role` can elevate to `admin`.
    """
    jwt_algorithm, jwt_secret = _get_jwt_settings()

    if not jwt_secret:
        raise HTTPException(status_code=500, detail='JWT secret is not configured')
    try:
        payload = jwt.decode(token, jwt_secret, algorithms=[jwt_algorithm])
        if not isinstance(payload, dict):
            raise HTTPException(status_code=401, detail='Invalid token payload')
        raw = payload.get('role', 'user')
        app_meta = payload.get('app_metadata')
        if isinstance(app_meta, dict) and app_meta.get('role'):
            payload['role'] = str(app_meta['role']).lower()
        elif raw == 'authenticated':
            # Supabase end-user access token
            payload['role'] = 'user'
        else:
            payload['role'] = str(raw).lower()
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail='Token has expired')
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail='Invalid token')


def get_current_user(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    token = _extract_bearer_token(authorization)
    return verify_jwt_token(token)


def require_roles(*allowed_roles: str) -> Callable[..., dict[str, Any]]:
    """
    FastAPI dependency factory for route-level role checks.
    """
    normalized = {r.lower() for r in allowed_roles}

    def _dependency(user: dict[str, Any] = Depends(get_current_user)) -> dict[str, Any]:
        role = str(user.get('role', 'user')).lower()
        if role not in normalized:
            raise HTTPException(status_code=403, detail='Insufficient role permissions')
        return user

    return _dependency


def build_rate_limit_middleware():
    """
    Simple in-memory rate limiter (per IP) for public-facing routes.
    """
    buckets: dict[str, deque[float]] = defaultdict(deque)
    public_prefixes = (
        '/process-message',
        '/submit-report',
        '/reports',
        '/clusters',
        '/audit-log',
        '/analytics',
        '/transcribe',
        '/session',
        '/telegram',
    )
    exempt_exact = {'/', '/health'}
    exempt_prefixes = ('/docs', '/redoc', '/openapi.json')

    async def _middleware(request, call_next):
        path = request.url.path
        if path in exempt_exact or path.startswith(exempt_prefixes):
            return await call_next(request)

        is_public = path.startswith(public_prefixes)
        if not is_public:
            return await call_next(request)

        client_ip = request.client.host if request.client else 'unknown'
        key = f'{client_ip}:public'
        now = time.monotonic()
        window_start = now - RATE_LIMIT_WINDOW_SEC
        q = buckets[key]

        while q and q[0] < window_start:
            q.popleft()

        if len(q) >= RATE_LIMIT_REQUESTS:
            return JSONResponse(
                status_code=429,
                content={
                    'detail': 'Rate limit exceeded',
                    'limit': RATE_LIMIT_REQUESTS,
                    'window_seconds': RATE_LIMIT_WINDOW_SEC,
                },
            )

        q.append(now)
        return await call_next(request)

    return _middleware
