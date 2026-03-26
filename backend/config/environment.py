"""
Environment validation and configuration for MapSumbong backend.
Ensures all required environment variables are set at startup.
"""

import os
from typing import Dict, List

class EnvironmentValidator:
    """Validates critical environment variables at startup."""
    
    # Required for all environments
    REQUIRED_VARS = {
        'SUPABASE_URL': 'Supabase project URL',
        'JWT_SECRET': 'JWT signing secret (minimum 32 chars)',
        'GEMINI_API_KEY': 'Google Gemini API key for AI processing',
    }
    
    # Required for Telegram integration
    TELEGRAM_VARS = {
        'TELEGRAM_BOT_TOKEN': 'Telegram bot token from @BotFather',
    }
    
    # Required for SMS integration (MVP: optional)
    SMS_GENERIC_VARS = {
        'SMS_GATEWAY_URL': 'SMS gateway endpoint URL for generic provider mode',
        'SMS_GATEWAY_KEY': 'API key for generic SMS gateway mode',
    }

    SMS_TWILIO_VARS = {
        'SMS_API_KEY': 'Twilio Account SID',
        'SMS_API_SECRET': 'Twilio Auth Token',
        'SMS_FROM_NUMBER': 'Twilio sender phone number',
    }

    SMS_STARTUP_VARS = {
        'SMS_API_KEY': 'Startup SMS provider API key',
    }

    SMS_PHILSMS_VARS = {
        'SMS_API_KEY': 'PhilSMS API key token',
    }
    
    # Recommended security settings
    SECURITY_VARS = {
        'ENVIRONMENT': 'development|staging|production',
        'CORS_ALLOW_ORIGINS': 'Comma-separated list of allowed CORS origins',
        'RATE_LIMIT_REQUESTS': 'Requests per window (default: 60)',
        'RATE_LIMIT_WINDOW_SEC': 'Rate limit window in seconds (default: 60)',
    }
    
    @staticmethod
    def validate_required() -> tuple[bool, List[str]]:
        """
        Validate that all required environment variables are set.
        
        Returns:
            (is_valid, missing_vars_list)
        """
        missing = []
        
        for var, description in EnvironmentValidator.REQUIRED_VARS.items():
            if not os.getenv(var):
                missing.append(f"  - {var}: {description}")
        
        return len(missing) == 0, missing
    
    @staticmethod
    def validate_optional() -> Dict[str, List[str]]:
        """
        Check optional features and return which are enabled/disabled.
        
        Returns:
            {
                'telegram': [status, warnings],
                'sms': [status, warnings],
                'security': [status, warnings],
            }
        """
        results = {
            'telegram': [],
            'sms': [],
            'security': [],
        }
        
        # Telegram
        telegram_ready = all(os.getenv(var) for var in EnvironmentValidator.TELEGRAM_VARS)
        if telegram_ready:
            results['telegram'].append('✓ Enabled')
        else:
            missing = [v for v in EnvironmentValidator.TELEGRAM_VARS if not os.getenv(v)]
            results['telegram'].append(f'⚠ Disabled (missing: {", ".join(missing)})')
        
        # SMS
        sms_provider = (os.getenv('SMS_PROVIDER', '') or '').strip().lower()
        if not sms_provider:
            results['sms'].append('⚠ Disabled (set SMS_PROVIDER to philsms, startup, twilio, or generic)')
        elif sms_provider == 'philsms':
            missing = [v for v in EnvironmentValidator.SMS_PHILSMS_VARS if not os.getenv(v)]
            sender_id = os.getenv('SMS_SENDER_ID') or os.getenv('SMS_SYSTEM_NUMBER') or os.getenv('SMS_FROM_NUMBER')
            if missing:
                results['sms'].append(f'⚠ Disabled (PhilSMS missing: {", ".join(missing)})')
            elif not sender_id:
                results['sms'].append('⚠ Disabled (PhilSMS requires SMS_SENDER_ID or SMS_SYSTEM_NUMBER)')
            else:
                results['sms'].append('✓ Enabled (PhilSMS provider configured)')
        elif sms_provider == 'startup':
            missing = [v for v in EnvironmentValidator.SMS_STARTUP_VARS if not os.getenv(v)]
            if missing:
                results['sms'].append(f'⚠ Disabled (startup missing: {", ".join(missing)})')
            else:
                results['sms'].append('✓ Enabled (startup provider configured)')
        elif sms_provider == 'twilio':
            missing = [v for v in EnvironmentValidator.SMS_TWILIO_VARS if not os.getenv(v)]
            if not missing:
                results['sms'].append('✓ Enabled (Twilio provider configured)')
            else:
                results['sms'].append(f'⚠ Disabled (Twilio missing: {", ".join(missing)})')
        elif sms_provider == 'generic':
            missing = [v for v in EnvironmentValidator.SMS_GENERIC_VARS if not os.getenv(v)]
            if not missing:
                results['sms'].append('✓ Enabled (generic SMS gateway configured)')
            else:
                results['sms'].append(f'⚠ Disabled (generic missing: {", ".join(missing)})')
        else:
            results['sms'].append(f'⚠ Disabled (unknown SMS_PROVIDER: {sms_provider})')
        
        # Security
        security_warnings = []
        env = os.getenv('ENVIRONMENT', 'development')
        
        if env == 'production':
            if len(os.getenv('JWT_SECRET', '')) < 32:
                security_warnings.append('JWT_SECRET too short (use 32+ chars)')
            if os.getenv('CORS_ALLOW_ORIGINS', '').count('*') > 0:
                security_warnings.append('CORS allows wildcard (*) - restrict for production')
        
        if security_warnings:
            results['security'] = security_warnings
        else:
            results['security'].append('✓ Security baseline met')
        
        return results
    
    @staticmethod
    def print_startup_report():
        """Print a human-readable startup report."""
        print("\n" + "="*70)
        print("MAPSUMBONG BACKEND - STARTUP VALIDATION")
        print("="*70)
        
        # Required validation
        is_valid, missing = EnvironmentValidator.validate_required()
        print("\n[1] REQUIRED ENVIRONMENT VARIABLES")
        if is_valid:
            print("  ✓ All required variables configured")
        else:
            print("  ✗ MISSING CRITICAL VARIABLES:")
            for msg in missing:
                print(msg)
            print("\n  Cannot start without these. Please check your .env file.")
            return False
        
        # Optional validation
        print("\n[2] OPTIONAL FEATURES")
        optional_status = EnvironmentValidator.validate_optional()
        for feature, status_list in optional_status.items():
            print(f"  {feature.upper()}:")
            for msg in status_list:
                print(f"    {msg}")
        
        # Print runtime info
        print("\n[3] RUNTIME CONFIGURATION")
        print(f"  Environment: {os.getenv('ENVIRONMENT', 'development')}")
        print(f"  Supabase URL: {os.getenv('SUPABASE_URL', '❌ not set')[:50]}...")
        print(f"  Gemini: {'✓ configured' if os.getenv('GEMINI_API_KEY') else '❌ not set'}")
        print(f"  Telegram: {'✓ configured' if os.getenv('TELEGRAM_BOT_TOKEN') else '⚠ optional'}")
        sms_provider = (os.getenv('SMS_PROVIDER', '') or '').strip().lower()
        if not sms_provider:
            sms_status = '⚠ optional'
        elif sms_provider == 'philsms':
            sender_id = os.getenv('SMS_SENDER_ID') or os.getenv('SMS_SYSTEM_NUMBER') or os.getenv('SMS_FROM_NUMBER')
            if not all(os.getenv(v) for v in EnvironmentValidator.SMS_PHILSMS_VARS):
                sms_status = '⚠ incomplete'
            elif not sender_id:
                sms_status = '⚠ incomplete (missing sender id)'
            else:
                sms_status = '✓ configured'
        elif sms_provider == 'startup':
            if not all(os.getenv(v) for v in EnvironmentValidator.SMS_STARTUP_VARS):
                sms_status = '⚠ incomplete'
            else:
                sms_status = '✓ configured'
        elif sms_provider == 'twilio':
            sms_status = '✓ configured' if all(os.getenv(v) for v in EnvironmentValidator.SMS_TWILIO_VARS) else '⚠ incomplete'
        elif sms_provider == 'generic':
            sms_status = '✓ configured' if all(os.getenv(v) for v in EnvironmentValidator.SMS_GENERIC_VARS) else '⚠ incomplete'
        else:
            sms_status = '⚠ unknown provider'

        print(f"  SMS Provider: {sms_provider or 'not_set'}")
        print(f"  SMS Gateway: {sms_status}")
        
        print("\n" + "="*70)
        print("✓ Backend is ready to start\n")
        return True
