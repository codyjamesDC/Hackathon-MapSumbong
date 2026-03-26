from dotenv import load_dotenv
load_dotenv()

import os
import tempfile
import time
from urllib.parse import quote

from typing import Optional

import httpx
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel
from supabase import create_client
from services.whisper_service import transcribe_audio
from utils.security import require_roles




router = APIRouter()

MAX_EVIDENCE_FILE_SIZE_BYTES = 15 * 1024 * 1024


def _has_text(value: Optional[str]) -> bool:
    return bool(value and str(value).strip())


def _annotate_resolution_state(report: dict) -> dict:
    status = str(report.get('status') or '').lower()
    is_resolved = status == 'resolved'
    has_note = _has_text(report.get('resolution_note'))
    has_photo = _has_text(report.get('resolution_photo_url'))
    resolution_complete = is_resolved and has_note and has_photo

    enriched = dict(report)
    enriched['resolution_complete'] = resolution_complete
    enriched['resolution_pending_proof'] = is_resolved and not resolution_complete
    return enriched


def _get_supabase():
    """Lazy-load so .env is always read before client creation."""
    return create_client(
        os.getenv('SUPABASE_URL'),
        os.getenv('SUPABASE_SERVICE_KEY'),
    )


def _sanitize_for_path_segment(value: str, fallback: str = 'file') -> str:
    cleaned = ''.join(ch if ch.isalnum() or ch in '._-' else '-' for ch in str(value or '').strip().lower())
    cleaned = '-'.join(part for part in cleaned.split('-') if part)
    return cleaned or fallback


def _encode_storage_path(path: str) -> str:
    return '/'.join(quote(part, safe='') for part in str(path).split('/') if part)


def _build_public_storage_url(bucket: str, object_path: str) -> str:
    supabase_url = (os.getenv('SUPABASE_URL') or '').rstrip('/')
    encoded_bucket = quote(bucket, safe='')
    return f'{supabase_url}/storage/v1/object/public/{encoded_bucket}/{_encode_storage_path(object_path)}'


async def _upload_resolution_file_to_storage(report_id: str, file: UploadFile, kind: str, bucket: str) -> str:
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail=f'{kind} file is required')

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail=f'{kind} file is empty')
    if len(data) > MAX_EVIDENCE_FILE_SIZE_BYTES:
        raise HTTPException(status_code=400, detail=f'{kind} file exceeds 15 MB limit')

    original_name = str(file.filename)
    dot_index = original_name.rfind('.')
    extension = _sanitize_for_path_segment(original_name[dot_index + 1:], '') if dot_index > -1 else ''
    base_name = original_name[:dot_index] if dot_index > -1 else original_name
    safe_base_name = _sanitize_for_path_segment(base_name, 'evidence')
    safe_report_id = _sanitize_for_path_segment(report_id, 'report')
    unique_suffix = f"{int(time.time() * 1000)}-{os.urandom(3).hex()}"
    object_name = f'{kind}-{safe_base_name}-{unique_suffix}.{extension}' if extension else f'{kind}-{safe_base_name}-{unique_suffix}'
    object_path = f'resolutions/{safe_report_id}/{object_name}'

    supabase_url = (os.getenv('SUPABASE_URL') or '').rstrip('/')
    service_key = os.getenv('SUPABASE_SERVICE_KEY') or os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    if not supabase_url or not service_key:
        raise HTTPException(status_code=500, detail='Supabase storage credentials are not configured')

    upload_url = f'{supabase_url}/storage/v1/object/{quote(bucket, safe="")}/{_encode_storage_path(object_path)}'
    headers = {
        'apikey': service_key,
        'Authorization': f'Bearer {service_key}',
        'x-upsert': 'true',
        'Content-Type': file.content_type or 'application/octet-stream',
    }

    async with httpx.AsyncClient(timeout=45.0) as client:
        response = await client.post(upload_url, headers=headers, content=data)

    if response.status_code >= 400:
        reason = response.text.strip() or response.reason_phrase or 'Upload failed'
        raise HTTPException(status_code=502, detail=f'Failed to upload {kind} file: {response.status_code} {reason}')

    return _build_public_storage_url(bucket, object_path)


# ── Request models ─────────────────────────────────────────────────────────────

class UpdateStatusRequest(BaseModel):
    status: str
    resolution_note: Optional[str] = None
    resolution_photo_url: Optional[str] = None
    updated_by: Optional[str] = None


class DeleteReportRequest(BaseModel):
    deleted_by: str
    reason: str


@router.get('/reports')
async def get_reports(
    status: Optional[str] = None,
    barangay: Optional[str] = None,
    urgency: Optional[str] = None,
    issue_type: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
    _user: dict = Depends(require_roles('user', 'admin')),
):
    try:
        supabase = _get_supabase()
        query = supabase.table('reports').select('*').eq('is_deleted', False)

        if status:
            query = query.eq('status', status)
        if barangay:
            query = query.eq('barangay', barangay)
        if urgency:
            query = query.eq('urgency', urgency)
        if issue_type:
            query = query.eq('issue_type', issue_type)

        query = query.order('created_at', desc=True).range(offset, offset + limit - 1)
        response = query.execute()
        reports = [_annotate_resolution_state(r) for r in (response.data or [])]

        return {
            'reports': reports,
            'total': len(reports),
            'limit': limit,
            'offset': offset,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get('/reports/{report_id}')
async def get_report(
    report_id: str,
    _user: dict = Depends(require_roles('user', 'admin')),
):
    try:
        response = _get_supabase().table('reports').select('*').eq('id', report_id).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    if not response.data:
        raise HTTPException(status_code=404, detail='Report not found')

    return _annotate_resolution_state(response.data[0])


@router.patch('/reports/{report_id}/status')
async def update_report_status(
    report_id: str,
    request: UpdateStatusRequest,
    user: dict = Depends(require_roles('user', 'admin')),
):
    role = (user.get('role') or 'user').lower()
    if role != 'admin' and request.status != 'reopened':
        raise HTTPException(
            status_code=403,
            detail='Residents may only set status to reopened',
        )

    supabase = _get_supabase()
    update_data = {'status': request.status}

    if request.resolution_note:
        update_data['resolution_note'] = request.resolution_note
    if request.resolution_photo_url:
        update_data['resolution_photo_url'] = request.resolution_photo_url

    try:
        existing = supabase.table('reports').select('id').eq('id', report_id).limit(1).execute()
        if not existing.data:
            raise HTTPException(status_code=404, detail='Report not found')

        update_result = supabase.table('reports').update(update_data).eq('id', report_id).execute()
        if update_result.data is not None and len(update_result.data) == 0:
            raise HTTPException(status_code=404, detail='Report not found')

        actor = request.updated_by or user.get('sub') or user.get('email') or 'system'
        supabase.table('audit_log').insert({
            'report_id': report_id,
            'action': 'status_change',
            'performed_by': actor,
            'new_value': request.status,
            'note': f'Status changed to {request.status}',
        }).execute()

        updated_row = update_result.data[0] if update_result.data else {'status': request.status}
        enriched = _annotate_resolution_state(updated_row)

        return {
            'success': True,
            'report_id': report_id,
            'new_status': request.status,
            'resolution_complete': enriched['resolution_complete'],
            'resolution_pending_proof': enriched['resolution_pending_proof'],
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete('/reports/{report_id}')
async def delete_report(
    report_id: str,
    request: DeleteReportRequest,
    _user: dict = Depends(require_roles('admin')),
):
    supabase = _get_supabase()
    try:
        existing = supabase.table('reports').select('id').eq('id', report_id).limit(1).execute()
        if not existing.data:
            raise HTTPException(status_code=404, detail='Report not found')

        update_result = supabase.table('reports').update({
            'is_deleted': True,
            'deleted_by': request.deleted_by,
        }).eq('id', report_id).execute()
        if update_result.data is not None and len(update_result.data) == 0:
            raise HTTPException(status_code=404, detail='Report not found')

        result = supabase.table('audit_log').insert({
            'report_id': report_id,
            'action': 'delete',
            'performed_by': request.deleted_by,
            'note': request.reason,
        }).execute()

        return {
            'success': True,
            'report_id': report_id,
            'audit_log_id': result.data[0]['id'],
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get('/clusters')
async def get_clusters(
    barangay: Optional[str] = None,
    alerted: Optional[bool] = None,
    limit: int = 50,
    _user: dict = Depends(require_roles('user', 'admin')),
):
    try:
        query = _get_supabase().table('clusters').select('*')

        if barangay:
            query = query.eq('barangay', barangay)
        if alerted is not None:
            query = query.eq('alerted', alerted)

        response = query.order('created_at', desc=True).limit(limit).execute()
        return {'clusters': response.data, 'total': len(response.data)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get('/audit-log')
async def get_audit_log(
    report_id: Optional[str] = None,
    action: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    _user: dict = Depends(require_roles('admin')),
):
    try:
        query = _get_supabase().table('audit_log').select('*')

        if report_id:
            query = query.eq('report_id', report_id)
        if action:
            query = query.eq('action', action)

        response = query.order('created_at', desc=True).range(offset, offset + limit - 1).execute()
        return {'logs': response.data, 'total': len(response.data)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post('/transcribe')
async def transcribe_voice(
    file: UploadFile = File(...),
    _user: dict = Depends(require_roles('user', 'admin')),
):
    """Transcribe an uploaded audio file using Whisper service."""
    if not file.filename:
        raise HTTPException(status_code=400, detail='Audio file is required')

    temp_path = None
    try:
        suffix = '.ogg'
        if '.' in file.filename:
            suffix = f".{file.filename.rsplit('.', 1)[-1]}"

        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp:
            temp_path = temp.name
            temp.write(await file.read())

        result = await transcribe_audio(temp_path)
        if result.get('error'):
            raise HTTPException(status_code=500, detail=result['error'])

        return {
            'success': True,
            'text': result.get('text', ''),
            'confidence': result.get('confidence', 0.0),
            'language': result.get('language', 'unknown'),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)


@router.post('/reports/{report_id}/resolution-evidence')
async def upload_resolution_evidence(
    report_id: str,
    written_report_file: Optional[UploadFile] = File(default=None),
    photo_evidence_file: Optional[UploadFile] = File(default=None),
):
    if not written_report_file and not photo_evidence_file:
        raise HTTPException(status_code=400, detail='At least one evidence file is required')

    bucket = os.getenv('SUPABASE_STORAGE_BUCKET', 'photos')

    try:
        existing = _get_supabase().table('reports').select('id').eq('id', report_id).limit(1).execute()
        if not existing.data:
            raise HTTPException(status_code=404, detail='Report not found')

        resolution_note_url = ''
        resolution_photo_url = ''

        if written_report_file:
            resolution_note_url = await _upload_resolution_file_to_storage(
                report_id,
                written_report_file,
                'report',
                bucket,
            )

        if photo_evidence_file:
            resolution_photo_url = await _upload_resolution_file_to_storage(
                report_id,
                photo_evidence_file,
                'photo',
                bucket,
            )

        return {
            'resolution_note': resolution_note_url,
            'resolution_photo_url': resolution_photo_url,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get('/analytics')
async def get_analytics(_user: dict = Depends(require_roles('admin'))):
    """
    Mock analytics payload for dashboard integration.
    This structure is intentionally stable and can be backed by DB queries later.
    """
    return {
        'summary': {
            'total_reports': 128,
            'open_reports': 74,
            'resolved_reports': 54,
            'critical_reports': 19,
            'resolution_rate_pct': 42.2,
            'avg_response_time_hours': 5.8,
        },
        'by_status': {
            'received': 41,
            'in_progress': 27,
            'repair_scheduled': 6,
            'resolved': 54,
            'reopened': 0,
        },
        'by_issue_type': [
            {'issue_type': 'flood', 'count': 34},
            {'issue_type': 'fire', 'count': 8},
            {'issue_type': 'road_damage', 'count': 21},
            {'issue_type': 'garbage', 'count': 16},
            {'issue_type': 'power_outage', 'count': 12},
            {'issue_type': 'other', 'count': 37},
        ],
        'by_barangay': [
            {'barangay': 'Nangka', 'count': 28},
            {'barangay': 'Marulas', 'count': 22},
            {'barangay': 'Malinta', 'count': 19},
            {'barangay': 'Poblacion', 'count': 17},
        ],
        'trend_last_7_days': [
            {'date': '2026-03-19', 'reports': 14, 'resolved': 5},
            {'date': '2026-03-20', 'reports': 18, 'resolved': 7},
            {'date': '2026-03-21', 'reports': 22, 'resolved': 9},
            {'date': '2026-03-22', 'reports': 16, 'resolved': 10},
            {'date': '2026-03-23', 'reports': 21, 'resolved': 8},
            {'date': '2026-03-24', 'reports': 19, 'resolved': 7},
            {'date': '2026-03-25', 'reports': 18, 'resolved': 8},
        ],
        'generated_at': '2026-03-25T00:00:00Z',
    }