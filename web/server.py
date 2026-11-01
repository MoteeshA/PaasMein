"""Local ONIT negotiation relay for the buyer website and PaasMein app."""
from threading import RLock
import os
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
lock = RLock()
sessions = {}
shops = {}


def json_body():
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


@app.get("/")
def buyer_home():
    return send_from_directory(".", "market.html")


@app.get("/buyer")
def buyer_page():
    return send_from_directory(".", "market.html")


@app.post("/api/register")
def register():
    data = json_body()
    shop_id = str(data.get("shop_id", "")).strip()
    if not shop_id:
        return jsonify(error="shop_id required"), 400
    with lock:
        session = sessions.setdefault(shop_id, {
            "shop_id": shop_id, "status": "idle", "call_id": 0,
            "rounds": 0, "history": [], "seller_reply": None,
        })
        session["shop_name"] = str(data.get("shop_name") or session.get("shop_name") or "Shop")
        session["onit_enabled"] = bool(data.get("onit_enabled", True))
        return jsonify(ok=True, session=session)


@app.route("/api/shops", methods=["GET", "PUT"])
def published_shops():
    """Read or upsert shop listings synchronized from the Android app."""
    if request.method == "GET":
        with lock:
            return jsonify(shops=list(shops.values()))
    data = json_body()
    entries = data.get("shops")
    if not isinstance(entries, list):
        return jsonify(error="shops must be a list"), 400
    accepted = 0
    with lock:
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            shop_id = str(entry.get("id", "")).strip()
            name = str(entry.get("name", "")).strip()
            if not shop_id or not name:
                continue
            shops[shop_id] = {**entry, "id": shop_id, "name": name}
            accepted += 1
    return jsonify(ok=True, synced=accepted)


@app.post("/api/buyer_offer")
def buyer_offer():
    data = json_body()
    shop_id = str(data.get("shop_id", "")).strip()
    question, offer = str(data.get("question", "")).strip(), str(data.get("offer", "")).strip()
    if not shop_id or not question or not offer:
        return jsonify(error="shop_id, question and offer are required"), 400
    with lock:
        listing = shops.get(shop_id)
        if listing and not listing.get("onit_enabled", True):
            return jsonify(error="ONIT is disabled for this shop"), 403
        session = sessions.setdefault(shop_id, {
            "shop_id": shop_id, "shop_name": "Shop", "onit_enabled": True,
            "status": "idle", "call_id": 0, "rounds": 0, "history": [],
        })
        if not session.get("onit_enabled", True):
            return jsonify(error="ONIT is disabled for this shop"), 403
        session.update(shop_name=str(data.get("shop_name") or session["shop_name"]),
                       buyer_question=question, buyer_offer=offer,
                       seller_reply=None, status="ringing")
        session["call_id"] += 1
        session["rounds"] += 1
        session["history"].append({"role": "buyer", "text": question, "offer": offer})
        return jsonify(ok=True, call_id=session["call_id"], round=session["rounds"])


@app.get("/api/status/<shop_id>")
def status(shop_id):
    with lock:
        session = sessions.get(shop_id)
        return jsonify(session if session else {"shop_id": shop_id, "status": "idle", "onit_enabled": False})


@app.post("/api/seller_reply")
def seller_reply():
    data = json_body()
    shop_id, reply = str(data.get("shop_id", "")).strip(), str(data.get("reply", "")).strip()
    if not shop_id or not reply:
        return jsonify(error="shop_id and reply are required"), 400
    with lock:
        session = sessions.get(shop_id)
        if not session or session.get("status") != "ringing":
            return jsonify(error="no active buyer offer"), 404
        is_inquiry = str(session.get("buyer_offer", "")).strip().lower() == "inquiry"
        if not is_inquiry:
            if reply not in ("accept", "decline") and not reply.startswith("counter:"):
                return jsonify(error="reply must be accept, decline or counter:<price>"), 400
            if reply.startswith("counter:") and not reply[8:].strip():
                return jsonify(error="counter price is required"), 400
        session["seller_reply"] = reply
        session["status"] = "replied"
        session["history"].append({"role": "seller", "text": reply})
        return jsonify(ok=True, call_id=session["call_id"])


@app.post("/api/reset/<shop_id>")
def reset(shop_id):
    with lock:
        session = sessions.get(shop_id)
        if session:
            session.update(status="idle", buyer_question=None, buyer_offer=None, seller_reply=None)
    return jsonify(ok=True)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("ONIT_PORT", "5001")), threaded=True)
