from flask import Flask, jsonify
import os
import platform
import datetime
import logging

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(name)s %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

START_TIME = datetime.datetime.utcnow()


@app.route("/")
def index():
    logger.info("Root endpoint hit")
    return jsonify({
        "service": "devops-challenge-api",
        "status": "running",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "environment": os.getenv("ENVIRONMENT", "development"),
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z"
    })


@app.route("/health")
def health():
    logger.info("Health check called")
    uptime_seconds = (datetime.datetime.utcnow() - START_TIME).total_seconds()
    return jsonify({
        "status": "healthy",
        "uptime_seconds": round(uptime_seconds, 2),
        "hostname": platform.node(),
        "python_version": platform.python_version()
    }), 200


@app.route("/metrics")
def metrics():
    logger.info("Metrics endpoint called")
    uptime_seconds = (datetime.datetime.utcnow() - START_TIME).total_seconds()
    return jsonify({
        "uptime_seconds": round(uptime_seconds, 2),
        "environment": os.getenv("ENVIRONMENT", "development"),
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "host": platform.node()
    }), 200


@app.errorhandler(404)
def not_found(e):
    logger.warning(f"404 - Path not found")
    return jsonify({"error": "not found"}), 404


@app.errorhandler(500)
def server_error(e):
    logger.error(f"500 - Internal server error: {e}")
    return jsonify({"error": "internal server error"}), 500


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    logger.info(f"Starting app on port {port}")
    app.run(host="0.0.0.0", port=port, debug=debug)
