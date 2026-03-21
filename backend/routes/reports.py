from dotenv import load_dotenv
load_dotenv()

import os

from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from supabase import create_client




router = APIRouter()


def _get_supabase():
    """Lazy-load so .env is always read before client creation."""
    return create_client(
        os.getenv('SUPABASE_URL'),
        os.getenv('SUPABASE_SERVICE_KEY'),
    )


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
):
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

    return {
        'reports': response.data,
        'total': len(response.data),
        'limit': limit,
        'offset': offset,
    }


@router.get('/reports/{report_id}')
async def get_report(report_id: str):
    response = _get_supabase().table('reports').select('*').eq('id', report_id).execute()

    if not response.data:
        raise HTTPException(status_code=404, detail='Report not found')

    return response.data[0]


@router.patch('/reports/{report_id}/status')
async def update_report_status(report_id: str, request: UpdateStatusRequest):
    supabase = _get_supabase()
    update_data = {'status': request.status}

    if request.resolution_note:
        update_data['resolution_note'] = request.resolution_note
    if request.resolution_photo_url:
        update_data['resolution_photo_url'] = request.resolution_photo_url

    try:
        supabase.table('reports').update(update_data).eq('id', report_id).execute()
        supabase.table('audit_log').insert({
            'report_id': report_id,
            'action': 'status_change',
            'performed_by': request.updated_by or 'system',
            'new_value': request.status,
            'note': f'Status changed to {request.status}',
        }).execute()

        return {'success': True, 'report_id': report_id, 'new_status': request.status}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete('/reports/{report_id}')
async def delete_report(report_id: str, request: DeleteReportRequest):
    supabase = _get_supabase()
    try:
        supabase.table('reports').update({
            'is_deleted': True,
            'deleted_by': request.deleted_by,
        }).eq('id', report_id).execute()

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
):
    query = _get_supabase().table('clusters').select('*')

    if barangay:
        query = query.eq('barangay', barangay)
    if alerted is not None:
        query = query.eq('alerted', alerted)

    response = query.order('created_at', desc=True).limit(limit).execute()
    return {'clusters': response.data, 'total': len(response.data)}


@router.get('/audit-log')
async def get_audit_log(
    report_id: Optional[str] = None,
    action: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
):
    query = _get_supabase().table('audit_log').select('*')

    if report_id:
        query = query.eq('report_id', report_id)
    if action:
        query = query.eq('action', action)

    response = query.order('created_at', desc=True).range(offset, offset + limit - 1).execute()
    return {'logs': response.data, 'total': len(response.data)}