import logging
import os
import sys
from logging.handlers import RotatingFileHandler


def setup_logging() -> None:
    """Initialize a centralized logging system to capture bugs during development.
    
    Sets up a root logger that writes to both console and a rotating file.
    It also hooks into sys.excepthook to log any unhandled exceptions.
    """
    # Create logs directory at project root
    here = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(here)))
    log_dir = os.path.join(project_root, "logs")
    os.makedirs(log_dir, exist_ok=True)
    
    log_file = os.path.join(log_dir, "whisper_crystals.log")

    # Root logger configuration
    root_logger = logging.getLogger()
    # While developing, DEBUG level is preferred to capture all details
    root_logger.setLevel(logging.DEBUG)

    # Prevent adding handlers multiple times if setup_logging is called multiple times
    if root_logger.handlers:
        return

    # Basic formatting
    formatter = logging.Formatter(
        fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # File handler with rotation (max 5MB per file, keeps 3 backups)
    file_handler = RotatingFileHandler(
        log_file, maxBytes=5 * 1024 * 1024, backupCount=3, encoding="utf-8"
    )
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)

    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO) # Console can be INFO to reduce noise, or DEBUG
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)

    # Hook to log unhandled exceptions
    def handle_unhandled_exception(exc_type, exc_value, exc_traceback):
        if issubclass(exc_type, KeyboardInterrupt):
            # Let KeyboardInterrupt exit the program normally
            sys.__excepthook__(exc_type, exc_value, exc_traceback)
            return
        root_logger.error("Unhandled exception", exc_info=(exc_type, exc_value, exc_traceback))

    sys.excepthook = handle_unhandled_exception

    logging.info("Centralized logging system initialized.")
