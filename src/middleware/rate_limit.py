from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=[os.getenv("RATE_LIMIT", "5 per minute")]
)

@app.after_request
def inject_headers(response):
    response.headers["X-RateLimit-Limit"] = str(limiter.current_limit.limit.amount)
    response.headers["X-RateLimit-Remaining"] = str(limiter.current_limit.remaining)
    return response 