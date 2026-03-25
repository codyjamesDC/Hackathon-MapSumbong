import os

import jwt
from fastapi import HTTPException

from utils.security import verify_jwt_token


def test_verify_jwt_token_valid_user_role(monkeypatch):
    monkeypatch.setenv('JWT_SECRET', 'test-secret')

    payload = {'sub': 'user-1', 'role': 'user'}
    token = jwt.encode(payload, 'test-secret', algorithm='HS256')

    decoded = verify_jwt_token(token)
    assert decoded['sub'] == 'user-1'
    assert decoded['role'] == 'user'


def test_verify_jwt_token_invalid_signature(monkeypatch):
    monkeypatch.setenv('JWT_SECRET', 'test-secret')

    payload = {'sub': 'user-1', 'role': 'user'}
    token = jwt.encode(payload, 'other-secret', algorithm='HS256')

    try:
        verify_jwt_token(token)
        assert False, 'Expected HTTPException'
    except HTTPException as exc:
        assert exc.status_code == 401


def test_verify_jwt_token_maps_authenticated_to_user(monkeypatch):
    monkeypatch.setenv('JWT_SECRET', 'test-secret')

    payload = {'sub': 'user-1', 'role': 'authenticated'}
    token = jwt.encode(payload, 'test-secret', algorithm='HS256')

    decoded = verify_jwt_token(token)
    assert decoded['role'] == 'user'
