# Backend Deployment and Monitoring Checklist

## Security Hardening
- [ ] Set ENVIRONMENT=production
- [ ] Set JWT_SECRET with high entropy value
- [ ] Set CORS_ALLOW_ORIGINS to explicit frontend origins
- [ ] Disable wildcard CORS in production
- [ ] Rotate all API keys and service keys before launch

## Runtime and Health
- [ ] Verify /health returns healthy
- [ ] Verify /ready returns ready=true
- [ ] Verify /metrics endpoint (admin token required)
- [ ] Enable request log retention in hosting platform

## Monitoring
- [ ] Configure uptime checks for /health
- [ ] Configure alert on /ready failures
- [ ] Configure alert on 5xx error spikes
- [ ] Track avg latency from /metrics

## Deployment
- [ ] Build Docker image from backend/Dockerfile
- [ ] Deploy with resource limits and restart policy
- [ ] Validate environment variables in deployment settings
- [ ] Smoke test auth-protected endpoints with valid JWT

## Post-Deploy Validation
- [ ] Send test /process-message request
- [ ] Send test /send-message request
- [ ] Confirm reports read/write flows
- [ ] Confirm audit-log access control
