import logging
import time

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task
def sample_background_task(user_email):
    """
    A sample task that simulates a long-running process.
    """
    logger.info(f"Starting background task for user: {user_email}")
    # Simulate work
    time.sleep(5)
    logger.info(f"Finished background task for user: {user_email}")
    return f"Processed {user_email}"
