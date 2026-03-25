"""
Structured logging for MapSumbong backend.
Replaces print() statements with proper logging.
"""

import logging
import logging.handlers
import os
from datetime import datetime

class StructuredLogger:
    """Centralized logging configuration for the backend."""
    
    _logger = None
    
    @classmethod
    def setup(cls, app_name: str = 'mapsumbong') -> logging.Logger:
        """
        Initialize structured logging with console and file handlers.
        
        Args:
            app_name: Name of the application for logging
            
        Returns:
            Configured logger instance
        """
        if cls._logger is not None:
            return cls._logger
        
        logger = logging.getLogger(app_name)
        logger.setLevel(logging.DEBUG)
        
        # Remove any existing handlers
        logger.handlers.clear()
        
        # Console handler - INFO and above
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_format = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(name)s: %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(console_format)
        logger.addHandler(console_handler)
        
        # File handler - DEBUG and above
        log_dir = 'logs'
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, f'{app_name}_{datetime.now().strftime("%Y%m%d")}.log')
        
        file_handler = logging.handlers.RotatingFileHandler(
            log_file,
            maxBytes=10*1024*1024,  # 10MB
            backupCount=5  # Keep 5 backup files
        )
        file_handler.setLevel(logging.DEBUG)
        file_format = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(name)s:%(filename)s:%(lineno)d - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(file_format)
        logger.addHandler(file_handler)
        
        cls._logger = logger
        logger.info(f'Logging initialized. Log file: {log_file}')
        return logger
    
    @classmethod
    def get(cls) -> logging.Logger:
        """Get the configured logger instance."""
        if cls._logger is None:
            return cls.setup()
        return cls._logger


# Convenience function
def get_logger(name: str) -> logging.Logger:
    """Get a logger for a specific module."""
    return logging.getLogger(name)
